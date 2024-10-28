#!/usr/bin/env python
# coding:utf-8
# 用于查询每个游戏服的所有vip玩家

import time
import logging
import pymysql
import sqlite3

# 导入mysql连接池管理
from DBUtils.PooledDB import PooledDB

import sys
reload(sys)
sys.setdefaultencoding("utf8")

import MG_DBProtocol_PB_pb2 as MHPB
gsMsgPb = MHPB.DB_VIPAssetData_PB()

########################################
# 定义查询VIP等级大于等于9的玩家
vip_level = 0

# 游戏服用户名与密码
'''
gsdb_user = 'IamUsername'
gsdb_passwd = 'A123!@#b200'
'''
gsdb_user = 'user'
gsdb_passwd = '123456'

# 登录服与充值库,lc：login和charge
'''
lc_user = 'IamUsername'
lc_passwd = 'A123!@#b200'
lc_host = 'iamIPaddress'
lc_port = 3306
'''
lc_user = 'user'
lc_passwd = '123456'
lc_host = 'iamIPaddress'
lc_port = 20306
########################################
# t_vip表结构
"""
/*
Navicat SQLite Data Transfer

Source Server         : query_vip
Source Server Version : 30714
Source Host           : :0

Target Server Type    : SQLite
Target Server Version : 30714
File Encoding         : 65001

Date: 2017-04-18 10:25:03
*/

PRAGMA foreign_keys = OFF;

-- ----------------------------
-- Table structure for t_vip
-- ----------------------------
DROP TABLE IF EXISTS "main"."t_vip";
CREATE TABLE "t_vip" (
"cid"  INTEGER,
"uid"  INTEGER,
"username"  TEXT(72),
"charname"  TEXT(72),
"viplevel"  INTEGER,
"sid"  INTEGER,
"sname"  TEXT(72),
"ltime"  TEXT(20)
);
"""
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

    file_name = "query_vip.db"
    s_conn = sqlite3.connect(file_name)

    # 创建用于查询username的连接与游标
    m_conn = mysql_conn(lc_host, lc_port, lc_user, lc_passwd, 'Login')
    m_cur = m_conn.cursor()

    # 创建用于查询最后登陆时间的连接与游标
    oss_conn = mysql_conn(lc_host, lc_port, lc_user, lc_passwd, 'oss')
    oss_cur = oss_conn.cursor()

    # 遍历需要查询的游戏数据库
    for host, port, dbname, sid, sname in getServerList():
        logger.info("{0} {1}".format(sid, sname))
        query = '''SELECT a.c_cid, a.c_uid, a.c_charname, b.c_vip_data FROM 
                   t_char_basic as a,t_char_vip as b WHERE a.c_cid = b.c_cid;'''
        vip_list = query_mysql_result(host, port, gsdb_user, 
                                      gsdb_passwd, dbname, query)
        for cid, uid, charname, t_viplevel in vip_list:
            try:
                gsMsgPb.ParseFromString(t_viplevel)
                viplevel = int(gsMsgPb.VIPLevel)
            except Exception:
                # logger.info('ERROR::{0},{1},{2},{3},{4},{5},{6},{7}'.format(host, port,
                #             dbname, sid, sname, cid, uid, charname))
                viplevel = 0
            
            # 跳过vip等级小于指定值的玩家
            if viplevel < vip_level: continue

            # 跳过last_time小于2016-01-01的玩家
            query = '''SELECT max(insertime) as last_time FROM login WHERE cid={0} AND 
                       uid={1};'''.format(cid, uid)
            oss_cur.execute(query)
            ret_ltime = oss_cur.fetchall()
            if ret_ltime:
                l_time = ret_ltime[0][0]
                if l_time:
                    ltime = time.mktime(time.strptime(str(l_time), "%Y-%m-%d %H:%M:%S"))
                else:
                    ltime = 0
            else:
                ltime = 0
            stime = time.mktime(time.strptime('2016-01-01', "%Y-%m-%d"))
            if ltime < stime: continue

            # 获取用户名
            query = "SELECT c_username FROM t_account WHERE c_uid = {0};".format(uid)
            m_cur.execute(query)
            ret_username = m_cur.fetchall()
            if ret_username:
                username = ret_username[0][0]
            else:
                username = 'null'
            
            data = [cid, uid, username, charname, viplevel, sid, sname, l_time]
            logger.info("{0}".format(str(data)))
            s_insert = '''INSERT INTO t_vip (cid, uid, username, charname, viplevel, 
                          sid, sname, ltime) VALUES ({cid},{uid},'{username}','{charname}',
                          {viplevel},{sid},'{sname}','{ltime}')'''.format(
                                                            cid = cid,
                                                            uid = uid,
                                                            username = username,
                                                            charname = charname,
                                                            viplevel = viplevel,
                                                            sid = sid,
                                                            sname = sname,
                                                            ltime = l_time)
            s_conn.execute(s_insert)
            s_conn.commit()

    else:
        logger.info("The loop is done.")
    
    s_conn.close()
    m_cur.close()
    m_conn.close()
    oss_cur.close()
    oss_conn.close()

    logger.info("Result in file: ./{0}".format(file_name))

    