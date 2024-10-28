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
server_list = execMysqlCommand('iamIPaddress', 3306, 'IamUsername', '123456', 'Login', query)

# 已登录玩家清单
login_play_list = set()
localtime = time.localtime(time.time())
query_start_time = '{0}-01-01'.format(localtime.tm_year)
query_end_time = time.strftime("%Y-%m-%d", time.localtime())
for i in range(1, localtime.tm_yday):
    query = ("SELECT DISTINCT uid,cid FROM Login{0} WHERE DATE_FORMAT(insertime,'%Y-%m-%d') "
        " BETWEEN '{1}' AND '{2}';".format(i, query_start_time, query_end_time))
    print query
    t_login_play_list = execMysqlCommand('iamIPaddress', 3306, 'IamUsername', '123456', 'OSS', query)
    for uid,cid in t_login_play_list:
        key = "{0}{1}".format(uid, cid)
        login_play_list.add(key)

conn = sqlite3.connect('gslist.db')
for sdbip,sdbport,sdbname,real_sid,real_sname in server_list:
    s_time = time.time()
    query = "SELECT DISTINCT c_cid,c_uid,c_charname from t_char_basic;"
    every_gs = execMysqlCommand(sdbip, sdbport, 'IamUsername', '123456', sdbname, query)
    conn_t = pymysql.connect(host='iamIPaddress', port=3306, user='IamUsername', passwd='123456', db='Login', charset="utf8")
    for c_cid,c_uid,c_charname in every_gs:
        ID = "{0}{1}".format(c_uid, c_cid)
        if ID not in login_play_list : continue
        query = "SELECT DISTINCT c_username FROM t_account where c_uid = {0}".format(c_uid)
        cur_t = conn_t.cursor()
        if cur_t.execute(query):
            t_username_list = cur_t.fetchall()
            c_username = t_username_list[0][0].encode("utf-8")
        else:
            c_username = 'null'
        cur_t.close()
        query = "SELECT ID FROM userlist WHERE ID='{0}';".format(ID)
        if conn.execute(query):
            query_update = ("UPDATE userlist SET charname='{0}',real_sid={1},real_sname='{2}',user='{3}'" 
                " WHERE ID='{4}';".format(c_charname, real_sid, real_sname, c_username, ID))
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
    end_time = time.time()
    print "{0},{1},{2}".format(end_time - s_time, real_sid, real_sname)
conn_t.close()        
conn.close()
