#!/usr/bin/env python
# coding:utf-8
# 用于查询泰国充值流水，匹配角色名
# by colin on 2016-09-01

import pymysql
import sys
import xlsxwriter
import time

# 设置编码为UTF8？
# 这样可以看到泰文字符
reload(sys)
sys.setdefaultencoding("utf8")
# 定义充值数据查询的时间范围
# 时间已经过处理，如下两个变量，查询的数据范围为：
# 2016-11-07 00:00:00 至 2016-11-15 23:59:59
start_time = '2016-11-07'
end_time = '2016-11-15'

# 设置Login库的连接信息，用于查询需要遍历的游戏数据库
# 数据样板："10.232.26.60",3310,"ProjectM"
l_host = "10.116.4.223"
l_port = 3306
l_dbname = "Login"
user = "user"
passwd = "123456"

l_conn = pymysql.connect(host=l_host, port=l_port, user=user, passwd=passwd, db=l_dbname, charset="utf8")
l_cur = l_conn.cursor()
l_cur.execute("select DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname from t_gameserver_list")
server_list = l_cur.fetchall()  # 所有游戏数据库
sql_charge = ("SELECT b.c_username,a.sid,a.uid,a.cid,a.totalmoney,a.time,a.gameCode FROM "
    "Charge.ThirdFinish a,Login.t_account b WHERE a.uid=b.c_uid AND DATE_FORMAT(a.time,'%Y-%m-%d') "
    " BETWEEN '{0}' AND '{1}'".format(start_time, end_time))
l_cur.execute(sql_charge)
charge_data = l_cur.fetchall()  # 所有玩家的充值数据
l_cur.close()
l_conn.close()

list_charname = {}

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

# 创建excle表格文件，保存匹配的数据
file_name = "/tmp/charge_data.xlsx"
workbook = xlsxwriter.Workbook(file_name)
t_format = workbook.add_format({'bold': True})
t_format.set_align('center')
t_format.set_align('vcenter')
data = ["c_username", "c_charname", "sid", "uid", "cid", "totalmoney", "time", "gamecode"]

for host, port, dbname, real_sid, real_sname in server_list:
    worksheet = workbook.add_worksheet(real_sname)
    worksheet.set_column(0, 7, 20)
    for i,t_data in enumerate(data):
        worksheet.write(0, i, t_data, t_format)

worksheet = workbook.add_worksheet("未匹配")
worksheet.set_column(0, 7, 20)
for i,t_data in enumerate(data):
    worksheet.write(0, i, t_data, t_format)

# 匹配充值数据与玩家角色名
for worksheet in workbook.worksheets():
    j = 1
    for c_username, sid, uid, cid, totalmoney, time, gamecode in charge_data:
        if cid in list_charname.keys():
            c_charname = list_charname[cid][0]
            real_sname = list_charname[cid][2]
        else:
            c_charname = "null"
            real_sname = "未匹配"
        t_data_tup = [ c_username,
                    c_charname,
                    sid,
                    uid,
                    cid,
                    int(totalmoney),
                    str(time),
                    str(gamecode) ]
        if real_sname == worksheet.get_name():
            for i,t_data in enumerate(t_data_tup):
                worksheet.write(j, i, t_data)
                # print t_data_tup
            j += 1
else:
    print "The loop is done."

workbook.close()
print file_name
