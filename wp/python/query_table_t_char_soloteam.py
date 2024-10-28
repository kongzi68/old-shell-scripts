#!/usr/bin/env python  
#coding:utf-8
# 用于查询玩家的侠客信息
# 只限于查询指定的侠客

import pymysql

##
# 设置Login库的连接信息，用于查询需要遍历的数据库
# 数据样板："iamIPaddress",3310,"ProjectM"
#
l_host = "iamIPaddress"
l_port = 3306
l_dbname = "Login"
user = "user"  # 用户名都用IamUsername
passwd = "123456"  # 这个密码不仅Login库可用，被查询出来的其它数据库也可以使用

l_conn = pymysql.connect(host=l_host, port=l_port, user=user, passwd=passwd, db=l_dbname)
l_cur = l_conn.cursor()
l_cur.execute("select DISTINCT real_sid,sdbip,sdbport,sdbname from t_gameserver_list")
server_list = l_cur.fetchall()
l_cur.close()
l_conn.close()

##
# 遍历查询出来的数据库
#
for real_sid, host, port, dbname in server_list:
    print real_sid, host, port, dbname
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd, db=dbname)
    cur = conn.cursor()
    file_name = "/tmp/query_c_chartype.txt"
    file1 = open(file_name, "a+")
    i = 0
    while i <= 7:
        sql = ("select c_chartype, count(*) as n from t_char_soloteam{0} where c_chartype in (20060,21060,22060) "
               "group by c_chartype having n > 1 order by c_chartype;".format(i))
        if cur.execute(sql):
            for c_chartype, count_num in cur.fetchall():
                try:
                    list_string = "{0}, {1}, {2}".format(real_sid, c_chartype, count_num)
                except TypeError, error_info:
                    print error_info
                    print list_string
                finally:
                    file1.write(list_string + "\n")
                    file1.flush()
        i += 1
    file1.close()
    cur.close()
    conn.close()
else:
    print "The loop is done."
