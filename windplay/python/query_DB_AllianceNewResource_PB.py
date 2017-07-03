#!/usr/bin/env python
# coding:utf-8
# 用于查询联盟元宝、黑铁、玄铁、盟魂、修炼等级、活跃度等
# by colin on 2016-09-28

import pymysql
import MG_DBProtocol_PB_pb2 as MHPB
gsMsgPb = MHPB.DB_AllianceNewResource_PB()
conn = pymysql.connect(host='10.130.49.2', port=3306, user='root', passwd='game@t6game', db='160926ProjectM2', charset="utf8")
cur = conn.cursor()
sql = "select c_new_data from t_alliance_list where c_name='SLoW_LiFe';"
cur.execute(sql)
aaa = cur.fetchone()
gsMsgPb.ParseFromString(aaa[0])
for t_list in ['AllianceTrainingLevel','AllianceLiveness','AllianceLastWeekLiveness','AllianceLastUpdateWLTime']:
    will_do = 'gsMsgPb.{0}'.format(t_list)
    print "{0}:{1}".format(t_list, eval(will_do))
cur.close()
conn.close()
