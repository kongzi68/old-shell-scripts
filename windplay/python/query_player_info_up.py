#!/usr/bin/env python
# coding:utf-8
# 用于查询全服玩家的角色名信息

import pymysql,time
import sqlite3
import sys
reload(sys)
sys.setdefaultencoding("utf8")

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
server_list = execMysqlCommand('10.221.124.144', 3306, 'root', '123456', 'Login', query)

# 已登录玩家清单
login_play_list = set()
login_uid = set()
for i in range(1,366):
    query = "SELECT DISTINCT uid,cid FROM Login{0} WHERE DATE_FORMAT(insertime,'%Y-%m-%d') BETWEEN '2016-01-01' AND '2016-12-31';".format(i)
    t_login_play_list = execMysqlCommand('10.221.168.131', 3306, 'root', '123456', 'OSS', query)
    for uid,cid in t_login_play_list:
        key = "{0}{1}".format(uid, cid)
        login_play_list.add(key)
        login_uid.add(uid)

# 拉取所有玩家的用户名信息
query = "SELECT DISTINCT c_uid,c_username FROM t_account;"
t_username_list = execMysqlCommand('10.221.124.144', 3306, 'root', '123456', 'Login', query)
from collections import defaultdict
username_list = defaultdict(list)
for c_uid,c_username in t_username_list:
    if c_uid in login_uid : username_list[c_uid] = c_username

conn = sqlite3.connect('gslist.db')
cursor = conn.execute("SELECT ID FROM userlist;")
id_list = set([ row[0] for row in cursor ])

for sdbip,sdbport,sdbname,real_sid,real_sname in server_list:
    print real_sid,real_sname
    query = "SELECT DISTINCT c_cid,c_uid,c_charname from t_char_basic;"
    every_gs = execMysqlCommand(sdbip, sdbport, 'root', '123456', sdbname, query)
    for c_cid,c_uid,c_charname in every_gs:
        s_time = time.time()
        c_username = username_list.get(c_uid)
        ID = "{0}{1}".format(c_uid, c_cid)
        if ID not in login_play_list:
            print time.time() - s_time
            continue
        if ID in id_list:
            query_update = ("UPDATE userlist SET charname='{0}',real_sid={1},real_sname='{2}'" 
                "WHERE ID='{3}';".format(c_charname, real_sid, real_sname, ID))
            conn.execute(query_update)
        else:
            query_insert = ("INSERT INTO userlist (ID,real_sid,real_sname,uid,user,cid,charname) "
                "VALUES ('{ID}',{real_sid},'{real_sname}',{uid},'{user}',{cid},'{charname}');".format(
                    ID=ID,
                    real_sid=real_sid,
                    real_sname=real_sname,
                    uid=c_uid,
                    user=c_username,
                    cid=c_cid,
                    charname=c_charname
                ))
            conn.execute(query_insert)
        conn.commit()
        print time.time() - s_time
conn.close()

