#!/usr/bin/env python
#coding=utf-8
# 查询玩家的VIP等级
# 查询玩家在指定期间内的留存情况

import pymysql, time
import xlsxwriter
import MG_DBProtocol_PB_pb2 as MHPB
import sys
reload(sys)
sys.setdefaultencoding("utf-8")

gsMsgPb = MHPB.DB_VIPAssetData_PB()

def execMysqlCommand(host,port,user,passwd,dbname,query):
    '''
    查询数据库，返回结果为嵌套元组
    '''
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd, db=dbname, charset="utf8")
    cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()
    cur.close()
    conn.close()
    return result

# 拉取所有游戏服数据库信息
query = "SELECT DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname FROM t_gameserver_list;"
server_list = execMysqlCommand('iamIPaddress', 3306, 'IamUsername', '123456', 'Login', query)

def getVipData(register_day):
    '''
    传入日期参数，查询并分析汇总结果
    '''
    # 期间新增的玩家
    query = "SELECT c_uid FROM t_account WHERE DATE_FORMAT(inserttime, '%Y-%m-%d')='{0}';".format(register_day)
    register_list = execMysqlCommand('iamIPaddress', 3306, 'IamUsername', '123456', 'Login', query)
    # 获取有效vip数据
    vip_dict = {}
    for c_uid in register_list:
        for sdbip,sdbport,sdbname,real_sid,real_sname in server_list:
            query = "SELECT c_cid,c_vip_data FROM t_char_vip WHERE c_cid IN (SELECT c_cid FROM t_char_basic WHERE c_uid = '{0}')".format(c_uid[0])
            player_list = execMysqlCommand(sdbip, sdbport, 'IamUsername', '123456', sdbname, query)
            for c_cid,c_vip_data in player_list:
                try:
                    gsMsgPb.ParseFromString(c_vip_data)
                    viplevel = str(gsMsgPb.VIPLevel)
                except TypeError, error_info:
                    viplevel = '0'
                if viplevel == '0' : continue
                if viplevel not in vip_dict.keys():
                    vip_dict[viplevel] = []
                vip_dict[viplevel].append([c_uid[0], c_cid])
    return vip_dict

filename = 'player_login_count.xlsx'
workbook = xlsxwriter.Workbook(filename)
t_format = workbook.add_format({'bold': True})
t_format.set_align('center')
t_format.set_align('vcenter')

# 生成统计总表
for register_day in range(18, 25):
    # 从2016-08-18至2016-08-25期间导入的玩家
    register_day = '2016-08-{0}'.format(register_day)
    vip_dict = getVipData(register_day)
    login_day = [1,2,3,7,14,20,25,30,60] # 留存天数
    worksheet = workbook.add_worksheet(register_day)
    worksheet.set_column(0, 10, 12)
    # 写入列标题
    worksheet.write(0, 0, 'vip等级', t_format)
    worksheet.write(0, 1, '玩家数量', t_format)
    for i, t_data in enumerate(login_day):
        worksheet.write(0, i+2, t_data, t_format)
    t_d_day = time.strptime('20160818', '%Y%m%d')
    # 处理有效vip数据
    for i, viplevel in enumerate(vip_dict.keys()):
        player_num = len(vip_dict.get(viplevel))
        # 每一行的前两列，写入VIP等级与该等级玩家数量
        worksheet.write(i+1, 0, viplevel)
        worksheet.write(i+1, 1, player_num)
        for j, d_day in enumerate(login_day):
            d_day += t_d_day.tm_yday
            num = 0
            for c_uid, c_cid in vip_dict.get(viplevel):
                query = "SELECT uid, cid FROM Login{0} WHERE uid = {1} AND cid = {2}".format(d_day, c_uid, c_cid)
                select_result = execMysqlCommand('iamIPaddress', 3306, 'IamUsername', '123456', 'OSS', query)
                if select_result: num += 1
            worksheet.write(i+1, j+2, num)  # 写入玩家留存
            print d_day, num
    print register_day
else:
    workbook.close()
    print 'The loop is done.'
    print 'The result in file: ./{0}'.format(filename)


