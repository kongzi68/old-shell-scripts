#!/usr/bin/env python
# coding:utf-8
# 用于查询角色名

import pymysql
import xlsxwriter
import sys
reload(sys)
sys.setdefaultencoding("utf8")

l_host = "10.221.124.144"
l_port = 3306
l_dbname = "Login"
user = "root"
passwd = "123456"

l_conn = pymysql.connect(host=l_host, port=l_port, user=user, passwd=passwd, db=l_dbname, charset="utf8")
l_cur = l_conn.cursor()
l_cur.execute("select DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname from t_gameserver_list")
server_list = l_cur.fetchall()  # 所有游戏数据库
l_cur.close()
l_conn.close()

workbook = xlsxwriter.Workbook("charname_data.xlsx")
t_format = workbook.add_format({'bold': True})
t_format.set_align('center')
t_format.set_align('vcenter')
data = ["sid", "uid", "cid", "c_charname", "level"]

worksheet = workbook.add_worksheet("角色清单")
worksheet.set_column(0, 5, 20)
i = 0
for t_data in data:
    worksheet.write(0, i, t_data, t_format)
    i += 1

list_uid = [
    10106073,
    10281135,
    10283307,
    5115878,
    8407249
]

# 遍历需要查询的游戏数据库
# 取出所有玩家的角色名
j = 1
for host, port, dbname, real_sid, real_sname in server_list:
    print host, port, dbname
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd, db=dbname, charset="utf8")
    cur = conn.cursor()
    cur.execute("SELECT c_cid,c_uid,c_charname,c_level FROM t_char_basic")
    list_info = []
    for c_cid,c_uid,c_charname,c_level in cur.fetchall():
        if c_uid in list_uid:
            list_info = [real_sid, c_uid, c_cid, c_charname, c_level]
            i = 0
            for t_data in list_info:
                worksheet.write(j, i, t_data)
                # print t_data_tup
                i += 1
            j += 1
    cur.close()
    conn.close()
workbook.close()

