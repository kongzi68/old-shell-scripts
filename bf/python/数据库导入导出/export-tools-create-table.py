#!/usr/bin/env python3
# 创建导包-连接数据库-连接pandas-读取sql文件-装入csv文件
import pymysql as pm

# 连接数据库
con = pm.connect(
    host='iamIPaddress',
    port=50031,
    user='simu4_tqtz',
    password='000000000000',
    database='CUS_FxND_DB'
)
cur = con.cursor()
cur.execute("show tables;")
#t_table_lists = cur.fetchall()
#print(t_table_lists)

# 连接目标数据库
con_dst = pm.connect(
    host='iamIPaddress',
    port=3310,
    user='IamUsername',
    password='Iampassword',
    database='cus_fund_db'
)
cur_dst = con_dst.cursor()


for item in cur.fetchall():
    #print(item)
    table_name = item[0]
    print(table_name)
    cur.execute("desc {0};".format(table_name))
    #print(cur.fetchall())
    #break
    c_names_list = []
    for c_items in cur.fetchall():
        c_name = c_items[0]
        c_type = c_items[1]

        if c_items[2] == 'NO':
            isnull_str = 'NOT NULL' 
        elif c_items[2] == 'YES':
            isnull_str = ''
        
        if c_items[4]:
            default_str = "DEFAULT '{0}'".format(c_items[4])
        elif c_items[4] == '':
            default_str = "DEFAULT ''"
        elif c_items[4] == None:
            default_str = "DEFAULT NULL"

        if c_name == 'id':
            t_c_name = "`{0}` {1} {2}".format(c_name, c_type, isnull_str)
        else:
            t_c_name = "`{0}` {1} {2} {3}".format(c_name, c_type, isnull_str, default_str)

        c_names_list.append(t_c_name)
        #c_names = "{0}, {1}".format(t_c_name, c_names)
    c_names = ",".join(c_names_list)
    #print(c_names)
    #print("CREATE TABLE `{0}` ( {1} ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;".format(table_name, c_names))
    create_table_sql = "CREATE TABLE `{0}` ( {1} ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;".format(table_name, c_names)
    print(create_table_sql)
    cur_dst.execute(create_table_sql)

    con_dst.commit()
    con.commit()

con_dst.close()
con.close()
