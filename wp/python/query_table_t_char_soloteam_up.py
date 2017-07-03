#!/usr/bin/env python
# coding:utf-8
# 用于查询全服玩家拥有重复侠客的问题

import pymysql
import sys
reload(sys)
sys.setdefaultencoding("utf-8")

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

conn_t = pymysql.connect(host='10.221.124.144', port=3306, user='root', passwd='123456', db='Login', charset="utf8")
for sdbip,sdbport,sdbname,real_sid,real_sname in server_list:
    for i in range(0, 8):
        query = ("select c.c_uid,c.c_charname,s.c_cid,s.c_chartype,count(s.c_chartype) as num from t_char_basic as c,t_char_soloteam{0} as s "
               " WHERE c.c_cid=s.c_cid group by s.c_cid,s.c_chartype having num > 1;".format(i))
        t_char_soloteam = execMysqlCommand(sdbip, sdbport, 'root', '123456', sdbname, query)
        for c_uid,c_charname,c_cid,c_chartype,num in t_char_soloteam:
            query = "SELECT DISTINCT c_username FROM t_account where c_uid = {0}".format(c_uid)
            cur_t = conn_t.cursor()
            if cur_t.execute(query):
                t_username_list = cur_t.fetchall()
                c_username = t_username_list[0][0].encode("utf-8")
            else:
                c_username = 'null'
            cur_t.close()
            print "{0}\t{1}\t{2}\t{3}\t{4}\t{5}".format(c_username, c_charname, c_cid, real_sname, c_chartype, num)
conn_t.close()
