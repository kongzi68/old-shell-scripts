#!/usr/bin/env python  
# !encoding:utf-8
# 用于查询用户的坐骑等级

import pymysql
import MG_DBProtocol_PB_pb2 as MHPB  # 这里引入自己编译的commonprotocol的py文件名

gsMsgPb = MHPB.DB_MountAsset_PB()  # 坐骑资产

# 设置Login库的连接信息，用于查询需要遍历的数据库
# 数据样板："iamIPaddress",3310,"ProjectM"
l_host = "iamIPaddress"
l_port = 3306
l_dbname = "Login"
user = "IamUsername"  
passwd = "123456" 

l_conn = pymysql.connect(host=l_host, port=l_port, user=user, passwd=passwd, db=l_dbname)
l_cur = l_conn.cursor()
l_cur.execute("select DISTINCT sdbip,sdbport,sdbname from t_gameserver_list")
server_list = l_cur.fetchall()
l_cur.close()
l_conn.close()

# 坐骑字段
"""
    MountID,
    CurrentLevel,
    CurrentExperience,
    FodderType,
    FodderExperience,
    CurrentPrayCount,
    SkillID,
    StateID,
    EnergyValue
"""

# 遍历查询出来的数据库
for host, port, db in server_list:
    print host, port, db
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd, db=db)
    cur = conn.cursor()
    #file_name = "/tmp/{0}_{1}.txt".format(host, port)
    file_name = "/tmp/mount_info.txt"
    file1 = open(file_name, "a+")
    sql = "select c_cid,c_mount_asset from t_char_newdata"
    a = cur.execute(sql)
    if a != 0:  # 当查询的结果为空时
        for c_cid, c_mount_asset in cur.fetchall():
            try:
                gsMsgPb.ParseFromString(c_mount_asset)  # 解密
                mount_num = len(gsMsgPb.MountInfo) - 1  # 计算坐骑数量并减1
            except TypeError, error_info:
                pass
            finally:
                if mount_num >= 0:  # 有很多角色的坐骑数据为空
                    i = 0
                    while i <= mount_num:  # while循环保存玩家坐骑信息到文本文档
                        try:
                            list_string = "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}".format(c_cid,
                                                                                           gsMsgPb.MountInfo[i].MountID,
                                                                                           gsMsgPb.MountInfo[
                                                                                               i].CurrentLevel,
                                                                                           gsMsgPb.MountInfo[
                                                                                               i].CurrentExperience,
                                                                                           gsMsgPb.MountInfo[
                                                                                               i].FodderType,
                                                                                           gsMsgPb.MountInfo[
                                                                                               i].FodderExperience,
                                                                                           gsMsgPb.MountInfo[
                                                                                               i].CurrentPrayCount,
                                                                                           gsMsgPb.MountInfo[i].SkillID,
                                                                                           gsMsgPb.MountInfo[i].StateID,
                                                                                           gsMsgPb.MountInfo[
                                                                                               i].EnergyValue)
                            file1.write(list_string + "\n")
                            file1.flush()
                            print list_string
                        except IndexError, error_info:
                            pass
                        i += 1
    file1.close()
    cur.close()
    conn.close()
else:
    print "The loop is done."
