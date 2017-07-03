#!/usr/bin/env python
# coding:utf-8
# 用于查询在指定期间内全服未登录过的玩家信息
# 结果:账号id、账号、角色id、角色名、区服、宝石情况、最后登录时间等

import time
import pymysql
import xlsxwriter
import sqlite3
import logging
import sys
import hashlib

# 导入mysql连接池管理
from DBUtils.PooledDB import PooledDB

import sys
reload(sys)
sys.setdefaultencoding("utf8")

# 定义sqlite3库名，用于存储信息
sql3db = 'dolist.db'

# 定义log日志格式
logger = logging.getLogger()
logger.setLevel(logging.INFO)
fh = logging.FileHandler('/tmp/test.log') 
ch = logging.StreamHandler()

# 定义handler的输出格式formatter
formatter = logging.Formatter('%(asctime)s %(levelname)s [line:%(lineno)d]:: %(message)s')
fh.setFormatter(formatter)
ch.setFormatter(formatter)
logger.addHandler(fh)
logger.addHandler(ch)

def getMd5(*args):
    '''
    接收任意个字符串参数，生成16位md5，做ID值用
    '''
    string = ''
    for arg in args:
        string = '{0}{1}'.format(string, arg)
    string = str(string).encode('utf-8')
    m = hashlib.md5()
    m.update(string)
    return m.hexdigest()

def query_mysql_result(host, port, user, passwd, dbname, query, 
                       dict_ret=False):
    '''
    查询数据库
    默认返回查询结果为嵌套元组；当dict_ret=True，返回结果为列表嵌套字典
    '''
    pool = PooledDB(creator=pymysql, mincached=1, maxcached=20, maxshared=20, 
                    maxconnections=20 ,maxusage=20000, host=host, port=port, 
                    user=user, passwd=passwd, db=dbname, charset="utf8")
    conn = pool.connection()

    if dict_ret:
        cur = conn.cursor(pymysql.cursors.DictCursor)
    else:
        cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()
    cur.close()
    conn.close()

    return result

def mysql_conn(host, port, user, passwd, dbname):
    '''
    返回连接
    '''
    pool = PooledDB(creator=pymysql, mincached=1, maxcached=20, maxshared=20, 
                    maxconnections=20 ,maxusage=20000, host=host, port=port, 
                    user=user, passwd=passwd, db=dbname, charset="utf8")
    conn = pool.connection()

    return conn

def get_login_play_list():
    '''
    返回结果为集合，已登录的uid清单
    '''
    login_play_list = set()
    localtime = time.localtime(time.time())
    query_start_time = '{0}-01-01'.format(localtime.tm_year)
    query_end_time = time.strftime("%Y-%m-%d", localtime)

    for i in range(1, localtime.tm_yday):
        query = '''SELECT DISTINCT uid FROM Login{0} WHERE 
                   DATE_FORMAT(insertime,'%Y-%m-%d') BETWEEN '{1}' 
                   AND '{2}';'''.format(i, query_start_time, query_end_time)
        logging.info(query)
        ret_query = query_mysql_result('10.221.168.131', 3306, 'root',
                                       '123456', 'OSS', query)
        for uid in ret_query:
            login_play_list.add(uid[0])

    return login_play_list

def get_charge_list():
    '''
    返回结果为集合，充值uid清单
    '''
    charge_list = set()
    query = '''SELECT DISTINCT uid FROM IOSFinish UNION 
               SELECT DISTINCT uid FROM TmallFinish;'''
    ret_query = query_mysql_result('10.221.124.144', 3306, 'root',
                                   '123456', 'Charge', query)
    for uid in ret_query:
        charge_list.add(uid[0])

    return charge_list

def open_gs_date(sid):
    '''
    查询开服时间,未开服返回字符串‘no_open’
    通过充值表，查询最早充值，粗略计算出开服时间
    '''
    ret = 'no_open'
    query = ''' SELECT sid, DATE_FORMAT(time, '%Y-%m-%d') AS ctime, 
                COUNT( DATE_FORMAT(time, '%Y-%m-%d')) AS num 
                FROM IOSFinish WHERE sid = {0} GROUP BY sid, ctime 
                HAVING num > 5 ORDER BY ctime LIMIT 1;'''.format(sid)
    ret_query = query_mysql_result('10.221.124.144', 3306, 'root',
                                   '123456', 'Charge', query, dict_ret=True)

    if ret_query: ret = ret_query[0]['ctime']
    return ret

def save_uids(uids, tab_name):
    '''
    传入参数为集合,结构必须为：('uid1','uid2',...)
    '''
    conn = sqlite3.connect(sql3db)
    try:
        for uid in uids:
            query = "SELECT uid FROM {0} WHERE uid = {1};".format(tab_name, uid)
            cursor = conn.execute(query)
            ret_query = cursor.fetchall()
            if not ret_query:
                query_insert = "INSERT INTO {0} (uid) VALUES ({1});".format(tab_name, uid)
                conn.execute(query_insert)
                conn.commit()
                msg = 'insert uid: {0} to table: {1}'.format(uid, tab_name)
                logging.info(msg)
    except Exception as error_info:
        logging.error(error_info)
        conn.close()
        sys.exit()

    conn.close()

def save_nologin_incharge_result(login_play_list, charge_list):
    '''
    参数login_play_list, charge_list必须为集合
    类似格式为:('uid1','uid2',...)
    '''
    # 拉取游戏服清单
    query = '''SELECT DISTINCT dbip,dbport,dbname,real_sid,real_sname 
               FROM t_gameserver_list; '''
    server_list = query_mysql_result('10.221.124.144', 3306, 'root', 
                                     '123456', 'Login', query)

    # 创建用于查询username的连接与游标
    conn = mysql_conn('10.221.124.144', 3306, 'root', '123456', 'Login')
    cur = conn.cursor()

    # 创建sqlite3游标，把符合条件的数据写入表t_list
    conn_lite = sqlite3.connect(sql3db)
    try:
        # 遍历需要查询的游戏数据库
        for host, port, dbname, real_sid, real_sname in server_list:
            # 排除开服时间大于'2016-01-01'的游戏服，2016年肯定登陆过啊
            open_day = open_gs_date(real_sid)
            msg = '遍历游戏服: {0},{1} 开服时间: {2}'.format(real_sid, real_sname, 
                                                             open_day)
            logging.info(msg)
            time.sleep(1)
            if open_day >= '2016-01-01' or open_day == 'no_open': 
                logging.info('开服时间大于‘2016-01-01’，该服的玩家必然登陆过')
                continue

            # 查询条件为最后登出时间小于'2016-01-01'
            query = '''SELECT c_uid, c_cid, c_charname, c_unbindgold, 
                       FROM_UNIXTIME(c_last_leave_time, '%Y-%m-%d') AS ltime
                       FROM t_char_basic WHERE 
                       FROM_UNIXTIME(c_last_leave_time, '%Y-%m-%d') < '2016-01-01';'''
            play_list = query_mysql_result(host, port, 'root', '123456', 
                                           dbname, query)
            # 遍历处理单个游戏服中的所有uid
            for uid, cid, charname, unbindgold, ltime in play_list:
                # 判断该UID是否符合条件
                if int(uid) not in login_play_list and int(uid) in charge_list:
                    # 获取用户名
                    query = '''SELECT c_username FROM t_account WHERE 
                               c_uid = {0};'''.format(uid)
                    cur.execute(query)
                    ret_username = cur.fetchall()
                    if ret_username:
                        username = ret_username[0][0]
                    else:
                        username = 'null'
                else:
                    continue

                # 符合条件的玩家，写入表t_list
                id = getMd5(uid, cid, real_sid) # 计算ID值
                query_select = '''SELECT id FROM t_list WHERE id = '{0}';'''.format(id)
                cursor_lite = conn_lite.execute(query_select)
                ret_query = cursor_lite.fetchall()
                if not ret_query:
                    query_insert = '''INSERT INTO t_list (id, uid, username, cid, 
                                    charname, gs, gold, last_leave_time, host, port, 
                                    dbname) VALUES ('{id}', '{uid}', '{username}', 
                                    '{cid}', '{charname}', '{gs}', '{gold}', '{ltime}', 
                                    '{host}', '{port}', '{dbname}');'''.format( 
                                    id=id, uid=uid, username=username, cid=cid, 
                                    charname=charname, gs=real_sname, gold=unbindgold, 
                                    ltime=ltime, host=host, port=port, dbname=dbname )
                    conn_lite.execute(query_insert)
                    conn_lite.commit()
                    msg = '''gs: {0}, sid:{1}, uid: {2}, cid: {3}'''.format(
                            real_sname, real_sid, uid, cid)
                    logging.info(msg)
                else:
                    msg = '''gs: {0}, sid:{1}, uid: {2}, cid: {3} already in 
                             the t_list.'''.format(real_sname, real_sid, uid, cid)
                    logging.info(msg)
    except Exception as error_info:
        logging.error(error_info)
        conn_lite.close()
        cur.close()
        conn.close()
        sys.exit()

    conn_lite.close()
    cur.close()
    conn.close()

if __name__ == '__main__':
    # 功能一
    # 把登陆的uid写入表t_login
    login_play_list = get_login_play_list()
    logging.info('开始把登陆过的uid写入表：t_login')
    time.sleep(2)
    save_uids(login_play_list, 't_login')
    logging.info('登陆过的所有uid，写入到t_login表完成')
    time.sleep(2)

    # 功能二
    # 把充值过的uid写入表t_charge
    charge_list = get_charge_list()
    logging.info('开始把充值过的uid写入表：t_charge')
    time.sleep(2)
    save_uids(charge_list, 't_charge')
    logging.info('充值过的所有uid，写入到t_charge表完成')
    time.sleep(2)

    # 功能三
    # 从sqlite库的两个表t_login,t_charge分别取uid生成集合
    logging.info('把uid不在登陆清单中的，且uid在充值清单中的玩家信息写入表t_list')
    conn = sqlite3.connect(sql3db)
    try:
        cursor = conn.execute('SELECT uid FROM t_login;') 
        login_play_list = { int(uid[0]) for uid in cursor.fetchall() }
        cursor = conn.execute('SELECT uid FROM t_charge;')
        charge_list = { int(uid[0]) for uid in cursor.fetchall() }
        save_nologin_incharge_result(login_play_list, charge_list)
        logging.info('符合条件的uid已筛选完毕，并成功写入t_list表')
        time.sleep(2)
    except Exception as error_info:
        logging.error(error_info)
    conn.close()

    # 功能四
    # 从t_list表取出符合条件的数据，清除其gold
    logging.info('现在开始清除符合条件的uid的宝石')
    conn = sqlite3.connect(sql3db)
    try:
        gs_cursor = conn.execute('select distinct gs,host,port,dbname from t_list;')
        gs_list = [ (gs,host,port,dbname) for gs,host,port,dbname in gs_cursor.fetchall() ]
        logging.info('成功取出需要遍历的游戏服清单')
        time.sleep(2)
    except Exception as error_info:
        logging.error('取出需要遍历的游戏服清单失败，{0}'.format(error_info))
        sys.exit()
    
    for gs, host, port, dbname in gs_list:
        logging.info("遍历游戏服: {0},{1}".format(gs, host))
        time.sleep(2)

        try:
            gs_query = '''SELECT id,uid,cid,gold FROM t_list WHERE host='{0}' AND gs='{1}' 
                          AND dbname='{2}';'''.format(host, gs, dbname)
            gs_ret_query = conn.execute(gs_query)
        except Exception as error_info:
            logging.error('取出需要清宝石的uid清单失败，{0}'.format(error_info))
            sys.exit()

        try:
            g_conn = mysql_conn(host, port, 'root', '123456', dbname)
            g_cur = g_conn.cursor()

            for id_num,uid,cid,gold in gs_ret_query.fetchall():
                try:
                    # 把玩家宝石更新为 0
                    update_query = '''UPDATE t_char_basic SET c_unbindgold = 0 WHERE 
                                      c_uid = {0} AND c_cid = {1};'''.format(uid, cid)
                    g_cur.execute(update_query)
                    g_conn.commit()
                    query_insert = '''INSERT INTO t_list_succeed (id,uid,cid,gold,gs) VALUES ('{id}',
                                     '{uid}','{cid}',{gold},'{gs}');'''.format( id=id_num, uid=uid, cid=cid, gold=gold, gs=gs)
                    conn.execute(query_insert)
                    msg = "清除uid: {0}, cid: {1}, id: {2}, {3}, {4} 的宝石成功".format(uid, cid, id_num, gs, host)
                    logging.info(msg)
                except Exception as error_info:
                    query_insert = '''INSERT INTO t_list_failed (id,uid,cid,gold,gs) VALUES ('{id}',
                                     '{uid}','{cid}',{gold},'{gs}');'''.format( id=id_num, uid=uid, cid=cid, gold=gold, gs=gs)
                    conn.execute(query_insert)
                    msg = "清除uid: {0}, cid: {1}, id: {2}, {3}, {4} 的宝石失败, {5}".format(uid, cid, id_num, gs, host, error_info)
                    logging.error(msg)
                finally:
                    conn.commit()
            g_cur.close()
            g_conn.close()
        except Exception as error_info:
            logging.error(error_info) 
            sys.exit()

    conn.close()
    logging.info('done.')



