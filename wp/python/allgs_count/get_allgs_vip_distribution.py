#!/usr/bin/env python
# coding:utf-8
# 用于查询全服活跃VIP玩家数据汇总
# 结果： viplevel ，player_num

import time
import logging
import pymysql

# 导入mysql连接池管理
from DBUtils.PooledDB import PooledDB

import sys
reload(sys)
sys.setdefaultencoding("utf8")

import MG_DBProtocol_PB_pb2 as MHPB
gsMsgPb = MHPB.DB_VIPAssetData_PB()

########################################
# 游戏服用户名与密码
gsdb_user = 'IamUsername'
gsdb_passwd = '123456'

# 登录服与充值库,lc：login和charge
lc_user = 'IamUsername'
lc_passwd = '123456'
lc_host = 'iamIPaddress'
lc_port = 3306
########################################

# 定义log日志格式
logger = logging.getLogger()
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
# 定义handler的输出格式formatter
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

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

def getServerList():
    '''
    拉取所有游戏服数据库信息
    返回：嵌套元组 ((),()...)
    '''
    query = '''SELECT DISTINCT sdbip,sdbport,sdbname,
            real_sid,real_sname FROM t_gameserver_list;'''
    server_list = query_mysql_result(lc_host, lc_port, lc_user,
                                     lc_passwd, 'Login', query)
    return server_list

if __name__ == '__main__':

    d_ret = {}

    # 遍历需要查询的游戏数据库
    for host, port, dbname, sid, sname in getServerList():
        logger.info("{0} {1}".format(sid, sname))
        query = '''SELECT a.c_cid, a.c_uid, b.c_vip_data, a.c_last_leave_time FROM 
                   t_char_basic as a,t_char_vip as b WHERE a.c_cid = b.c_cid;'''
        vip_list = query_mysql_result(host, port, gsdb_user, 
                                      gsdb_passwd, dbname, query)
        for cid, uid, t_viplevel, lltime in vip_list:
            try:
                gsMsgPb.ParseFromString(t_viplevel)
                viplevel = int(gsMsgPb.VIPLevel)
            except Exception:
                viplevel = 0

            # 5月3日8点整的时间戳为: 1493769600
            if int(lltime) < 1493769600: continue

            if viplevel not in d_ret.keys(): d_ret[viplevel] = []
            d_ret[viplevel].append([sid, cid, uid])
   
    for item in d_ret.keys():
        print "{0}\t{1}".format(item, len(d_ret[item]))  

    logger.info("done.")
