#!/usr/bin/env python
# coding:utf-8
# 用于查询在指定期间内全服未登录过的玩家信息
# 结果是玩家列表清单，包含：玩家信息，vip等级，宝石数量等

import time
import pymysql
import sqlite3
import sys
reload(sys)
sys.setdefaultencoding("utf8")

import MG_DBProtocol_PB_pb2 as MHPB

gsMsgPb = MHPB.DB_VIPAssetData_PB()

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
query = "SELECT DISTINCT sdbip,sdbport,sdbname,real_sid FROM t_gameserver_list;"
server_list = execMysqlCommand('10.221.124.144', 3306, 
                               'root', '123456', 'Login', query)

# 已登录玩家清单
login_play_list = set()
localtime = time.localtime(time.time())
query_start_time = '{0}-01-01'.format(localtime.tm_year)
query_end_time = time.strftime("%Y-%m-%d", localtime)
for i in range(1, localtime.tm_yday):
    query = ("SELECT DISTINCT uid,cid FROM Login{0} WHERE "
        " DATE_FORMAT(insertime,'%Y-%m-%d') "
        " BETWEEN '{1}' AND '{2}';".format(i, query_start_time, query_end_time))
    print query
    t_login_play_list = execMysqlCommand('10.221.168.131', 3306, 'root',
                                         '123456', 'OSS', query)
    for uid,cid in t_login_play_list:
        key = "{0}{1}".format(uid, cid)
        login_play_list.add(key)

# 充值玩家清单
charge_list = set()
query = ("SELECT DISTINCT uid,cid FROM IOSFinish "
        " UNION SELECT DISTINCT uid,cid FROM TmallFinish;")
t_charge_list = execMysqlCommand('10.221.124.144', 3306, 'root',
                                 '123456', 'Charge', query)
for uid,cid in t_charge_list:
    key = "{0}{1}".format(uid, cid)
    charge_list.add(key)

j = 1
sconn = sqlite3.connect('nologin_play.db')
# 遍历需要查询的游戏数据库
for host, port, dbname, real_sid in server_list:
    print host, port, dbname, real_sid
    # if real_sid in [10100010,10100011,10100037,10100061]:continue
    query = "SELECT c_cid,c_uid,c_charname,c_unbindgold FROM t_char_basic;"    
    play_list = execMysqlCommand(host, port, 'root', '123456', dbname, query)
    conn = pymysql.connect(host=host, port=port, user='root',
                           passwd='123456', db=dbname, charset="utf8")
    for c_cid,c_uid,c_charname,c_unbindgold in play_list:
        str_time = time.time()
        cur = conn.cursor()
        # query = ("SELECT DISTINCT c_logic_sid FROM t_uid_sid_map WHERE c_uid = {0} "
        #      " AND c_cid = {1};".format(c_uid, c_cid))
        # try:
        #     cur.execute(query)
        #     sid_list = cur.fetchall()
        #     sid = sid_list[0][0]
        # except Exception:
        #     sid = real_sid
        a_play = "{0}{1}".format(c_uid, c_cid)
        end1_time = time.time()
        if a_play not in login_play_list and a_play in charge_list:
            end2_time = time.time()
            query = "SELECT c_vip_data FROM t_char_vip WHERE c_cid={0}".format(c_cid)
            try:
                cur.execute(query)
                vipinfo = cur.fetchall()
                gsMsgPb.ParseFromString(vipinfo[0][0])
                viplevel = str(gsMsgPb.VIPLevel)
            except TypeError:
                viplevel = '0'
            end3_time = time.time()
            squery = ("INSERT INTO nologin (ID,sid,cid,uid,charname,gold,viplevel) "
                " VALUES ('{ID}','{sid}','{cid}','{uid}','{charname}','{gold}', "
                "'{viplevel}');".format(
                    ID = j,
                    sid = real_sid,
                    cid = c_cid,
                    uid = c_uid,
                    charname = c_charname,
                    gold = c_unbindgold,
                    viplevel = viplevel))
            sconn.execute(squery)
            if j % 1000 == 0: sconn.commit()
            j += 1
            end4_time = time.time()
            print j,(end1_time - str_time),(end2_time - end1_time),(end3_time - end2_time),(end4_time - end3_time)
        cur.close()
    conn.close()

sconn.close()
print 'done.'

