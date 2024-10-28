#!/usr/bin/env python  
# !encoding:utf-8
# 用于查询玩家突破等级

import pymysql
import MG_DBProtocol_PB_pb2 as MHPB  ####这里引入自己编译的commonprotocol的py文件名

# gsMsgPb = MHPB.ST_Char_Equipments() ##这里先new一个你需要的协议的对象出来，ST_Char_Equipments就是协议名（具体的要根据业务在proto里面去找）
gsMsgPb = MHPB.DB_ActorTrainData_PB()  ##这里先new一个你需要的协议的对象出来，ST_Char_Equipments就是协议名（具体的要根据业务在proto里面去找）

# 协议详细内容如下，（只为方便你来做参考，实际的程序中不用含以下'''中的内容）
"""
message ST_Char_Equipments
{
	message TEquipPossiveInfoOneFightModel
	{
		required int32 FightModel = 1;
		repeated ST_Vector3Int_PB EquipPossiveSkills = 2;
	}
	
	optional ST_Asset_BackPackEntry_PB Weapon=1;
	optional ST_Asset_BackPackEntry_PB Cuirass =2;
	optional ST_Asset_BackPackEntry_PB Armet = 3;
	optional ST_Asset_BackPackEntry_PB Leg = 4;
	optional ST_Asset_BackPackEntry_PB Shoe = 5;
	optional ST_Asset_BackPackEntry_PB Necklace = 6;
	optional ST_Asset_BackPackEntry_PB Badge = 7;
	optional ST_Asset_BackPackEntry_PB Ring = 8;
	repeated int32 EquipPassiveSkillList = 9;
	repeated TEquipPossiveInfoOneFightModel EquipPossiveSkillList = 10;
}
"""

##
# 设置Login库的连接信息，用于查询需要遍历的数据库
# 数据样板："iamIPaddress",3310,"ProjectM"
#
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

##
# 遍历查询出来的数据库
#
for host, port, dbname in server_list:
    print host, port, dbname
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd, db=dbname)
    cur = conn.cursor()
    file_name = "/tmp/{0}_{1}.txt".format(host, port)
    file1 = open(file_name, "a+")
    i = 0
    while i <= 7:
        sql = ("select c_cid,c_chartype,c_train_data from t_char_soloteam{0} where "
               "c_chartype like '210%' OR c_chartype like '200%' OR c_chartype like '220%'".format(i))
        a = cur.execute(sql)
        # 当查询的结果为空时
        if a != 0:
            for c_cid, c_type, c_train in cur.fetchall():
                try:
                    gsMsgPb.ParseFromString(c_train)  # 这里把需要解析的字段用ParseFromString解析就可以了
                    list_string = "{0}, {1}, {2}".format(c_cid, c_type, gsMsgPb.TrainAttributeMaxAdditionCount)
                except TypeError, error_info:
                    print error_info
                    print list_string
                finally:
                    file1.write(list_string + "\n")
                    file1.flush()
        i += 1
    file1.close()
    cur.close()
    conn.close()
else:
    print "The loop is done."
