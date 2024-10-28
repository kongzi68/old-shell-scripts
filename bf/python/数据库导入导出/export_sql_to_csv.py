# 创建导包-连接数据库-连接pandas-读取sql文件-装入csv文件
import pandas as pd
import pymysql as pm
import os
# 连接数据库
con = pm.connect(
    host='iamIPaddress',
    port=50031,
    user='simu4_tqtz',
    password='000000000',
    database='CUS_FxsD_DB'
)
cur = con.cursor()
cur.execute("show tables;")
#t_table_lists = cur.fetchall()
#print(t_table_lists)
for item in cur.fetchall():
    #print(item)
    table_name = item[0]
    #print(table_name)
    csv_name = "{0}.csv".format(table_name)
    if not os.path.isfile(csv_name):
        print("正在导出文件{0}".format(csv_name))
        pdf = pd.read_sql("select * from {0}".format(table_name), con)
        pdf.to_csv(csv_name)
        del pdf
    con.commit()

con.close()
