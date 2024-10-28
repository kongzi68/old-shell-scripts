#!/usr/bin/env python
# coding:utf-8
# 用于查询联盟积分
# by colin on 2016-09-26

import pymysql
import MG_DBProtocol_PB_pb2 as MHPB

gsMsgPb = MHPB.DB_AllianceAsset_PB()

host = "iamIPaddress"
port = 3306
dbname = "baiyubin_test"
user = "colin"
passwd = "123456"

charname_list=(
    '13928921723;50;锦瑟＆楚千离',
    'pmb0555;41;曼妙漾',
    'ucudng;50;暴走的小牛',
    'xyc117;42;锦瑟&必剩客',
    '66433174;28;随意的风',
    'weishukezi;43;护心毛',
    'sunnyp;43;☆有☆天☆',
    'szslk110;46;锦瑟&海芋恋',
    'xhning;43;锦瑟&吾豪',
    'shihongboq;50;李英俊',
    'wzm198410;30;器宇非凡',
    'caosangni;35;宇落凡尘'
)

conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd, db=dbname, charset="utf8")
#conn = pymysql.connect(host='iamIPaddress', port=3306, user='colin', passwd='123456', db='baiyubin_test')
cur = conn.cursor()

file_name = "/tmp/score_info.txt"
file1 = open(file_name, "a+")

for list_info in charname_list:
    UID = list_info.split(';')[0]
    ADDRESS = list_info.split(';')[1]
    CHARNAME = list_info.split(';')[2]
    sql = "select c_alliance_asset from t_char_newdata where c_cid=(select c_cid from t_char_basic where c_charname='{0}');".format(CHARNAME)
    ccc = cur.execute(sql)
    if ccc != 0:  
        aaa = cur.fetchone()
        gsMsgPb.ParseFromString(aaa[0])
        list_string = "{0};;{1};;{2};;{3}".format(UID,ADDRESS,CHARNAME,gsMsgPb.AllianceScore)
        print list_string
        file1.write(list_string + "\n")
        file1.flush()
    else:
        print list_info
file1.close()
cur.close()
conn.close()