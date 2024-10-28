#!/usr/bin/env python
# coding:utf-8
# 用于查询每个游戏服充值TOP50\100的玩家

import pymysql
import xlsxwriter
import sys
reload(sys)
sys.setdefaultencoding("utf8")

import MG_DBProtocol_PB_pb2 as MHPB

# 定义查询排行前50或100位玩家
limit_num = 50

# 游戏服用户名与密码
gsdb_user = 'user'
gsdb_passwd = '123456'

# 登录服与充值库,lc：login和charge
lc_user = 'user'
lc_passwd = '123456'
lc_host = 'iamIPaddress'
lc_port = 3306

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
query = '''SELECT DISTINCT sdbip,sdbport,sdbname, real_sid,real_sname FROM 
           t_gameserver_list;'''
server_list = execMysqlCommand(lc_host, lc_port, lc_user, lc_passwd, 'Login', query)

# 创建excle表格文件，保存匹配的数据
file_name = "query_charge_top{0}.xlsx".format(limit_num)
workbook = xlsxwriter.Workbook(file_name)
t_format = workbook.add_format({'bold': True})
t_format.set_align('center')
t_format.set_align('vcenter')

# 遍历需要查询的游戏数据库
for host,port,dbname,sid,sname in server_list:
    print sid,sname
    play_list_dic = {}
    query = ('''SELECT c_cid, c_uid, c_charname, c_level, 
        FROM_UNIXTIME(c_last_leave_time) AS last_logout FROM t_char_basic;''')
    play_list = execMysqlCommand(host, port, gsdb_user, 
                                 gsdb_passwd, dbname, query)
    for c_cid,c_uid,c_charname,c_level,last_logout in play_list:
        play_list_dic["{0}{1}".format(c_uid,c_cid)] = {'charname':c_charname,
                                                       'level':c_level,
                                                       'last_logout':last_logout}
    query = '''SELECT c.sid, c.uid, c.cid, c.time, sum(c.totalmoney) AS money, 
            l.c_username FROM Login.t_account AS l, Charge.ThirdFinish AS c 
            WHERE l.c_uid = c.uid AND c.sid = {0} GROUP BY c.cid 
            ORDER BY money DESC LIMIT {1};'''.format(sid, limit_num)
    charge_top_list = execMysqlCommand(lc_host, lc_port, lc_user,
                                       lc_passwd, 'Charge', query)
    data = ["序号", "游戏服ID", "游戏服名", "角色名", "角色ID", "用户名",
            "用户ID", "充值总金额", "角色等级", "VIP等级", "最后登录时间",
            "最后支付时间"]
    worksheet = workbook.add_worksheet(sname)
    worksheet.set_column(0, 12, 15)
    for i, item in enumerate(data):
        worksheet.write(0, i, item, t_format)
    j = 1
    for sid,uid,cid,charge_last_time,money,username in charge_top_list:
        # 解密vip等级
        query = "SELECT c_vip_data FROM t_char_vip WHERE c_cid='{0}'".format(cid)
        t_vip_info = execMysqlCommand(host, port, gsdb_user,
                                      gsdb_passwd, dbname, query)
        try:
            gsMsgPb.ParseFromString(t_vip_info[0][0])
            viplevel = int(gsMsgPb.VIPLevel)
        except Exception:
            viplevel = 0
        # if viplevel < 12 : continue
        key = "{0}{1}".format(uid,cid)
        if key in play_list_dic.keys():
            charname = play_list_dic[key]['charname']
            level = play_list_dic[key]['level']
            last_logout = play_list_dic[key]['last_logout']
        data = [j, sid, sname, charname, cid, username, uid, money, level,
                viplevel, str(last_logout), str(charge_last_time)]
        for i, t_data in enumerate(data):
            worksheet.write(j, i, t_data)
        j += 1
else:
    print "The loop is done."
workbook.close()