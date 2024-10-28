#!/usr/bin/env python
# coding:utf-8
# 用于查询在指定期间内全服未登录过的玩家信息
# 结果为一个统计总数

import time
import pymysql
import xlsxwriter
import sys
reload(sys)
sys.setdefaultencoding("utf8")

def execMysqlCommand(host,port,user,passwd,dbname,query):
    '''
    查询数据库，返回结果为嵌套元组
    '''
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd,
                           db=dbname, charset="utf8")
    cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()
    cur.close()
    conn.close()
    return result

# 拉取所有游戏服数据库信息
query = "SELECT DISTINCT sdbip,sdbport,sdbname FROM t_gameserver_list;"
server_list = execMysqlCommand('iamIPaddress', 3306, 'IamUsername', '123456',
                               'Login', query)

# 已登录玩家清单
login_play_list = set()
localtime = time.localtime(time.time())
query_start_time = '{0}-01-01'.format(localtime.tm_year)
query_end_time = time.strftime("%Y-%m-%d", localtime)
for i in range(1, localtime.tm_yday):
    query = '''SELECT DISTINCT uid,cid FROM Login{0} 
               WHERE DATE_FORMAT(insertime,'%Y-%m-%d') 
               BETWEEN '{1}' AND '{2}';'''.format(i, query_start_time,
                                                  query_end_time)
    t_login_play_list = execMysqlCommand('iamIPaddress', 3306, 'IamUsername', 
                                         '123456', 'OSS', query)
    print i,query
    for uid,cid in t_login_play_list:
        key = "{0}{1}".format(uid, cid)
        login_play_list.add(key)

# 充值玩家清单
charge_list = set()
query = '''SELECT DISTINCT uid,cid FROM IOSFinish 
           UNION SELECT DISTINCT uid,cid FROM TmallFinish;'''
t_charge_list = execMysqlCommand('iamIPaddress', 3306, 'IamUsername', '123456',
                                 'Charge', query)
for uid,cid in t_charge_list:
    key = "{0}{1}".format(uid, cid)
    if key not in charge_list:
        charge_list.add(key)

# 遍历需要查询的游戏数据库
total_gold = 0
for host, port, dbname in server_list:
    query = "SELECT c_cid,c_uid,c_charname,c_unbindgold FROM t_char_basic;"    
    play_list = execMysqlCommand(host, port, 'IamUsername', '123456', dbname, query)
    t_total_gold = 0 
    for c_cid,c_uid,c_charname,c_unbindgold in play_list:
        a_play = "{0}{1}".format(c_uid, c_cid)
        if a_play not in login_play_list and a_play in charge_list:
            t_total_gold = t_total_gold + c_unbindgold
    print host, port, dbname, t_total_gold
    total_gold = total_gold + t_total_gold

file = open('gold_charname_data.txt','w+')
file.write(str(total_gold) + "\n")
file.flush()
file.close()
print total_gold

