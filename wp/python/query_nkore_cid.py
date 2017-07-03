#!/usr/bin/env python
# coding:utf-8
# by colin on 2016-09-09

import pymysql
import sys
import xlsxwriter
import ast

# 设置编码为UTF8？
# 这样可以看到泰文字符
reload(sys)
sys.setdefaultencoding("utf8")

# 设置Login库的连接信息，用于查询需要遍历的游戏数据库
# 数据样板："10.232.26.60",3310,"ProjectM"
l_host = "10.0.201.25"
l_port = 3306
l_dbname = "login"
user = "sgh_svc"
passwd = "123456"

l_conn = pymysql.connect(host=l_host, port=l_port, user=user, passwd=passwd, db=l_dbname, charset="utf8")
l_cur = l_conn.cursor()
l_cur.execute("select DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname from t_gameserver_list")
server_list = l_cur.fetchall()  # 所有游戏数据库
l_cur.close()
l_conn.close()

# 遍历需要查询的游戏数据库
# 取出所有玩家的角色名
for host, port, dbname, real_sid, real_sname in server_list:
    print host, port, dbname
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd, db=dbname, charset="utf8")
    cur = conn.cursor()
    cur.execute("SELECT c_cid,c_charname FROM t_char_basic")
    for c_cid, c_charname in cur.fetchall():
        list_charname[c_cid] = [c_charname, real_sid, real_sname]
    cur.close()
    conn.close()