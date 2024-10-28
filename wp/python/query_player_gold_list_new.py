#!/usr/bin/env python
# coding:utf-8
# 用于查询在指定期间内全服未登录过的玩家信息
# 结果:账号id、账号、角色id、角色名、区服、宝石情况、最后登录时间等

import time
import pymysql
import xlsxwriter

# 导入mysql连接池管理
from DBUtils.PooledDB import PooledDB

import sys
reload(sys)
sys.setdefaultencoding("utf8")

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
        print query
        ret_query = query_mysql_result('iamIPaddress', 3306, 'IamUsername',
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
    ret_query = query_mysql_result('iamIPaddress', 3306, 'IamUsername',
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
    ret_query = query_mysql_result('iamIPaddress', 3306, 'IamUsername',
                                   '123456', 'Charge', query, dict_ret=True)

    if ret_query: ret = ret_query[0]['ctime']
    return ret


if __name__ == '__main__':
    # 拉取游戏服清单
    query = '''SELECT DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname 
               FROM t_gameserver_list; '''
    server_list = query_mysql_result('iamIPaddress', 3306, 'IamUsername', 
                                     '123456', 'Login', query)
    # 创建excel表格存储数据
    filename = 'no_login_play_list.xlsx'
    workbook = xlsxwriter.Workbook(filename)
    tab_format = workbook.add_format({'bold': True})
    tab_format.set_align('center')
    tab_format.set_align('vcenter')
    worksheet = workbook.add_worksheet('sheet1')
    worksheet.set_column(0, 6, 10)
    data = ['账号ID', '账号', '角色ID', '角色名', '游戏服', '宝石', '流失时间']
    for column, item in enumerate(data):
        worksheet.write(0, column, item, tab_format)

    login_play_list = get_login_play_list()
    charge_list = get_charge_list()

    # 创建用于查询username的连接与游标
    conn = mysql_conn('iamIPaddress', 3306, 'IamUsername', '123456', 'Login')
    cur = conn.cursor()

    # 遍历需要查询的游戏数据库
    j = 1
    for host, port, dbname, real_sid, real_sname in server_list:
        print host, port, dbname, real_sid, real_sname

        # 排除开服时间大于'2016-01-01'的游戏服，2016年肯定登陆过啊
        open_day = open_gs_date(real_sid)
        if open_day >= '2016-01-01' or open_day == 'no_open': continue

        # 创建该游戏服的mysql连接
        gs_conn = mysql_conn(host, port, 'IamUsername', '123456', dbname)
        gs_cur = gs_conn.cursor()

        query = '''SELECT c_uid, c_cid, c_charname, c_unbindgold, 
                   c_last_leave_time FROM t_char_basic;'''
        play_list = query_mysql_result(host, port, 'IamUsername', '123456', 
                                       dbname, query)
        # 遍历处理单个游戏服中的所有uid
        for uid, cid, charname, unbindgold, ltime in play_list:
            str_time = time.time()
            # 判断该UID是否符合条件
            if uid not in login_play_list and uid in charge_list:
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
            
            last_leave_time = time.strftime("%Y-%m-%d", time.localtime(ltime))
            ltime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(ltime))

            # 最后登出时间大于等于'2016-01-01'的排除
            if last_leave_time >= '2016-01-01': continue

            # 符合条件的玩家，写入excel
            a_play = [uid, username, cid, charname, real_sname, unbindgold, ltime]        
            for column, item in enumerate(a_play):
                worksheet.write(j, column, item)

            # 把玩家宝石更新为 0
            """
            update_query = '''UPDATE t_char_basic SET c_unbindgold = 0 WHERE 
                              c_uid = {0} AND c_cid = {1};'''.format(uid, cid)
            gs_cur.execute(update_query)
            gs_conn.commit()
            """

            # if j % 5000 == 0: time.sleep(1)
            j += 1
            end_time = time.time()
            print (end_time - str_time),uid, username, cid, charname, real_sname, unbindgold, ltime

        gs_cur.close()
        gs_conn.close()

    cur.close()
    conn.close()
    workbook.close()
    print 'result in file: ./{0}'.format(filename)
