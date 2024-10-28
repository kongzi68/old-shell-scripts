#!/usr/bin/env python
#coding=utf-8
# 查询玩家在指定期间内按职业统计的留存情况

import pymysql, time, copy
import xlsxwriter
import sys
reload(sys)
sys.setdefaultencoding("utf-8")

def execMysqlCommand(host,port,user,passwd,dbname,query):
    '''
    查询数据库，返回结果为嵌套元组
    '''
    conn = pymysql.connect(host=host,
                            port=port,
                            user=user,
                            passwd=passwd,
                            db=dbname,
                            charset="utf8")
    cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()
    cur.close()
    conn.close()
    return result

# 拉取所有游戏服数据库信息
query = "SELECT DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname FROM t_gameserver_list;"
server_list = execMysqlCommand('iamIPaddress',
                                3306,
                                'IamUsername',
                                '123456',
                                'Login',
                                query)

def getCharTypeData(query):
    '''
    传入日期参数，查询并分析汇总结果
    '''
    # 期间新增的玩家
    register_list = execMysqlCommand('iamIPaddress',
                                        3306,
                                        'IamUsername',
                                        '123456',
                                        'Login',
                                        query)
    chartype_dict = {}
    # aaa = 0
    for c_uid in register_list:
        for sdbip,sdbport,sdbname,real_sid,real_sname in server_list:
            query = ("SELECT c_cid,c_level,CASE WHEN c_chartype IN (10001, 10002) THEN 'kl' "
                " WHEN c_chartype IN (10003, 10004) THEN 'wd' "
                " WHEN c_chartype IN (10005, 10006) THEN 'mj' "
                " WHEN c_chartype IN (10007, 10008) THEN 'gb' "
                " WHEN c_chartype IN (10009, 10010) THEN 'xy' END AS chartype "
                " FROM t_char_basic WHERE c_uid = '{0}'".format(c_uid[0]))
            player_list = execMysqlCommand(sdbip, sdbport, 'IamUsername', '123456', sdbname, query)
            if player_list:
                for c_cid,c_level,chartype in player_list:
                    # aaa += 1
                    # print c_cid,c_level,chartype,aaa
                    if chartype not in chartype_dict.keys():
                        chartype_dict[chartype] = []
                    chartype_dict[chartype].append([c_uid[0], c_cid, c_level])
    return chartype_dict

filename = 'player_login_count_by_chartype.xlsx'
workbook = xlsxwriter.Workbook(filename)
tab_format = workbook.add_format({'bold': True})
tab_format.set_align('center')
tab_format.set_align('vcenter')

# 按天数统计新增各职业数量
worksheet = workbook.add_worksheet('新增各职业数量')
worksheet.set_column(0, 6, 12)
tab_tag = ['date','wd','kl','mj','gb','xy']
day_chartype_list = []
for column,tab_data in enumerate(tab_tag):
    worksheet.write(0, column, tab_data, tab_format)
for row in range(1, 8):
    # 从2016-08-18至2016-08-24期间导入的玩家
    register_day = '2016-08-{0}'.format(17 + row)
    query = ("SELECT c_uid FROM t_account WHERE "
            " DATE_FORMAT(inserttime, '%Y-%m-%d') = '{0}'".format(register_day))
    result_day = getCharTypeData(query)
    day_chartype_list.append(result_day)
    for column,tab_data in enumerate(tab_tag):
        if tab_data == 'date':
            data = register_day
        else:
            try:
                data = len(result_day.get(tab_data))
            except TypeError:
                data = 0
        worksheet.write(row, column, data)
        print register_day, tab_data, data

# 按天数统计新增玩家各职业充值总额
worksheet = workbook.add_worksheet('充值汇总')
worksheet.set_column(0, 6, 12)
for column, tab_data in enumerate(tab_tag):
    worksheet.write(0, column, tab_data, tab_format)
for row, chartype_dict in enumerate(day_chartype_list):
    register_day = '2016-08-{0}'.format(18 + row)
    for column, tag in enumerate(tab_tag):
        if tag == 'date':
            data = register_day
        else:
            sum_money = 0
            for c_uid, c_cid, _ in chartype_dict.get(tag):
                query = ("SELECT sum(totalmoney) FROM IOSFinish WHERE "
                        " DATE_FORMAT(time, '%Y-%m-%d') = '{0}' "
                        " AND uid = '{1}' "
                        " AND cid = '{2}' ".format(register_day, c_uid, c_cid))
                result_money = execMysqlCommand('iamIPaddress',
                                                3306,
                                                'IamUsername',
                                                '123456',
                                                'Charge',
                                                query)
                try:
                    sum_money += result_money[0][0]
                except TypeError:
                    sum_money += 0
                    print register_day, c_uid, c_cid
            data = sum_money
        worksheet.write(row + 1, column, data)
        print register_day, tag, data

# 按等级统计各职业留存
query = ("SELECT c_uid FROM t_account WHERE DATE_FORMAT(inserttime, '%Y-%m-%d') "
        " BETWEEN '2016-08-18' AND '2016-08-24'; ")
register_all = getCharTypeData(query)
copy_register_all = copy.deepcopy(register_all)
login_day = [1,2,3,7,14,20,25,30,60] # 留存天数
t_d_day = time.strptime('20160818', '%Y%m%d')
for d_day in login_day:
    worksheet = workbook.add_worksheet('留存{0}'.format(d_day))
    worksheet.set_column(0, 6, 10)
    tab_tag = ['level','wd','kl','mj','gb','xy']
    for column, item in enumerate(tab_tag):
        worksheet.write(0, column, item, tab_format)
    d_day += t_d_day.tm_yday
    for column, chartype in enumerate(tab_tag):
        if chartype != 'level':
            temp_list = copy_register_all.get(chartype)
            # 临时列表清理未登录的玩家
            for i, item in enumerate(temp_list):
                c_uid, c_cid, _ = item
                query = ("SELECT uid, cid FROM Login{0} WHERE uid = {1} "
                        " AND cid = {2} ".format(d_day, c_uid, c_cid))
                select_result = execMysqlCommand('iamIPaddress',
                                                3306,
                                                'IamUsername',
                                                '123456',
                                                'OSS',
                                                query)
                if not select_result: temp_list.pop(i)
        for level in range(1, 61):
            if chartype == 'level':
                worksheet.write(level, column, level)
            else:
                all_level = zip(*temp_list)[2]  # 计算玩家1~60各等级数量
                worksheet.write(level, column, all_level.count(level))

workbook.close()
print 'result in file: ./{0}'.format(filename)
