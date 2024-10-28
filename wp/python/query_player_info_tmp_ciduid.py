#!/usr/bin/env python
# coding:utf-8
# 用于查询全服玩家的角色名信息

import pymysql
import sqlite3
import sys
reload(sys)
sys.setdefaultencoding("utf8")

# c_cid,c_uid
# 这个列表中的每个值，由cid与uid组合
# cid在前，uid在后
cid_list = [
470130976643637,
440247472358039,
350089981496408,
480017545839835,
310803691370906,
530555128132056,
320249166077530,
320112941335681,
470362156748317,
10019288167247,
450835442790556,
790039057146357
]

cid_list = set(cid_list)

def execMysqlCommand(host,port,user,passwd,dbname,query):
    '''
    查询数据库，返回结果为嵌套元组
    '''
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd, db=dbname, charset="utf8")
    cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()
    cur.close()
    conn.close()
    return result

# 拉取所有游戏服数据库信息
query = "SELECT DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname FROM t_gameserver_list;"
server_list = execMysqlCommand('iamIPaddress', 3306, 'IamUsername', '123456', 'Login', query)

for sdbip,sdbport,sdbname,real_sid,real_sname in server_list:
    query = "SELECT DISTINCT c_cid,c_uid,c_charname from t_char_basic;"
    every_gs = execMysqlCommand(sdbip, sdbport, 'IamUsername', '123456', sdbname, query)
    for c_cid,c_uid,c_charname in every_gs:
        key = "{0}{1}".format(c_cid,c_uid)
        if int(key) in cid_list:
            print "{0}\t{1}\t{2}".format(c_cid,c_charname,real_sname)
