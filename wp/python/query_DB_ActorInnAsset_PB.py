#!/usr/bin/env python
# coding:utf-8
# 用于查询玩家魂魄丢失数据

import pymysql,sys,os
import xlsxwriter
import MG_DBProtocol_PB_pb2 as MHPB
reload(sys)
sys.setdefaultencoding('utf-8')

gsMsgPb = MHPB.DB_ActorInnAsset_PB()

# 玩家的数据,游戏服ID(sid)，UID，CID, real_sid
player_info = { 
    'sid':10100110,
    'uid':9584155,
    'cid':19009787,
    'real_sid':10100110,
}

def execMysqlCommand(host,port,user,passwd,dbname,query):
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd, db=dbname, charset="utf8")
    cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()
    cur.close()
    conn.close()
    return result

file_name = 'query_energy.xlsx'
os.system("rm {0} -f".format(file_name))
workbook = xlsxwriter.Workbook(file_name)
t_format = workbook.add_format({'bold': True})
t_format.set_align('center')
t_format.set_align('vcenter')

# 导出魂魄产出与消耗
for tname in ('Add','Reduce'):
    query = ("SELECT serverid,uid,cid,level,src,count,insertime,LogicServerID "
        " from {3}Energy where serverid={0} and uid={1} and cid={2};".format(
            player_info['real_sid'],
            player_info['uid'],
            player_info['cid'],
            tname
        ))
    query_result = execMysqlCommand('10.116.4.245', 3306, 'windplay', '123456', 'OSS_record', query)
    line_num = len(query_result) + 1
    worksheet = workbook.add_worksheet("{0}Energy".format(tname))
    worksheet.set_column(0, 7, 12)
    worksheet.add_table('A1:H{0}'.format(line_num), {
            'data': query_result,
            'header_row': False,
            'style': 'Table Style Light 11'
        })
    data = ['serverid', 'uid', 'cid', 'level', 'src', 'count', 'insertime', 'LogicServerID']
    for i, t_data in enumerate(data):
        worksheet.write(0, i, t_data, t_format)

# 导出玩家现有的魂魄数据
# 先从Login库查询玩家所在的游戏数据库
# 再从这个数据库查询魂魄数据并进行解密
query = "select DISTINCT sdbip,sdbport,sdbname from t_gameserver_list where sid={0};".format(player_info['sid'])
query_result = execMysqlCommand('10.116.4.223', 3306, 'windplay', '123456', 'Login', query)
(sdbip, sdbport, sdbname) = query_result[0]
query = "select c_inn_data from t_char_basic where c_cid={0} and c_uid={1};".format(player_info['cid'], player_info['uid'])
query_result = execMysqlCommand(sdbip, sdbport, 'windplay', '123456', sdbname, query)
gsMsgPb.ParseFromString(query_result[0][0])
worksheet = workbook.add_worksheet("Energy")
worksheet.write('A1', '当前魂魄数量')
worksheet.write('B1', gsMsgPb.SoulEnergy)
workbook.close()
print "result in file: ./{0}".format(file_name)