#!/usr/bin/env python
# coding:utf-8
# 功能说明：
# 查询oss_record库中的 ADDitem表，拉取玩家获得的物品信息
# 返回数据为: SID, UID, 角色名

import pymysql
import xlsxwriter
import time
import logging

# 导入mysql连接池管理
from DBUtils.PooledDB import PooledDB

import sys
reload(sys)
sys.setdefaultencoding("utf8")

# 定义log日志格式
logger = logging.getLogger()
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
# 定义handler的输出格式formatter
formatter = logging.Formatter('%(asctime)s %(levelname)s [line:%(lineno)d]:: %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

# 数据库用户名与密码
db_user = 'user'
db_passwd = '123456'

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

def get_games_db_lists():
    '''
    从登录服的t_gameserver_list获取游戏服数据库列表
    返回结果为：字典，{key:[], ...}
    '''
    ret = {}
    query = '''select real_sid, real_sname, sdbip, sdbport, sdbname, group_concat(sid) as sids
               from t_gameserver_list group by real_sid;'''
    q_ret = query_mysql_result('10.0.202.221', 20306, db_user, db_passwd, 'login', query)

    for rsid, sname, sdbip, sdbport, sdbname, sids in q_ret:
        ret[sids] = [rsid, sname, sdbip, sdbport, sdbname]

    return ret

if __name__ == '__main__':
    # 查询玩家获取指定物品ID的信息
    logging.info('正在查询有效的玩家数据')
    query = '''SELECT DISTINCT serverid,uid,cid FROM AddItem WHERE itemid=10000005 
               AND src=23 AND itemnum=5 AND DATE_FORMAT(insertime,'%Y-%m-%d') = '2017-02-28';'''
    q_ret = query_mysql_result('10.0.203.228', 20306, db_user, db_passwd, 'oss_record', query)

    group_uid = {}
    for sid, uid, cid in q_ret:
        if sid not in group_uid.keys(): group_uid[sid] = []
        group_uid[sid].append([uid, cid])

    logging.info('拉取玩家数据成功，开始匹配玩家角色名')

    gs_lists = get_games_db_lists()
    logging.info('成功拉取游戏服数据库列表')

    # 获取玩家的角色名
    ret = []
    for sid, items in group_uid.items():
        for sids, gs_db in gs_lists.items():
            if str(sid) in sids:
                rsid, sname, sdbip, sdbport, sdbname = gs_db

        logging.info('正在匹配属于游戏服{0}的角色名'.format(sname))
        conn = mysql_conn(sdbip, sdbport, db_user, db_passwd, sdbname)
        cur = conn.cursor()
        for uid, cid in items:
            query = '''SELECT c_charname FROM t_char_basic WHERE c_uid={0} AND 
                       c_cid={1};'''.format(uid, cid)
            cur.execute(query)
            q_ret = cur.fetchall()
            try:
                charname = q_ret[0][0]
            except Exception:
                pass
            ret.append([rsid, sname, uid, cid, charname])
            logging.info('{0},{1},{2},{3},{4}'.format(rsid, sname, uid, cid, charname))
        cur.close()
        conn.close()

    logging.info('玩家角色名匹配完成，将把数据导出到excel')

    # 把数据(嵌套列表 ret )写入excel表
    file_name = "oss_record_additem.xlsx"
    workbook = xlsxwriter.Workbook(file_name)
    worksheet = workbook.add_worksheet('sheet1')
    col_data = [{'header': 'SID'}, {'header': 'SNAME'}, {'header': 'UID'}, 
                {'header': 'CID'}, {'header': 'charname'}]
    worksheet.set_column(0, len(col_data) - 1, 15)
    tab_addrs = 'A1:{0}{1}'.format(chr(64 + len(col_data)), len(ret) + 1)
    options = {'data': ret,
               'style': 'Table Style Light 11',
               'columns': col_data}
    worksheet.add_table(tab_addrs, options)
    logging.info('数据写入excel完成')
    workbook.close()
    logging.info('Result in file: ./{0}'.format(file_name))

