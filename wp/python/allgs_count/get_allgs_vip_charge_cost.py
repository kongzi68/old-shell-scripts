#!/usr/bin/env python
#coding=utf-8
# 按当前VIP统计，统计不同VIP玩家在不同付费点消耗的宝石、
#+ 不同VIP等级玩家在商城购买的道具汇总消耗
import datetime
import logging
import os
import sys
import time
import pymysql
import xlsxwriter
from DBUtils.PooledDB import PooledDB

reload(sys)
sys.setdefaultencoding("utf-8")

import MG_DBProtocol_PB_pb2 as MHPB
gsMsgPb = MHPB.DB_VIPAssetData_PB()

#--------------------------
dbuser = 'root'
dbpasswd = '123456'
dbhost = '10.221.124.144'
dbport = 3306
#--------------------------

# 定义log日志格式
logger = logging.getLogger()
logger.setLevel(logging.INFO)
dir_name, _ = os.path.split(os.path.abspath(sys.argv[0]))
fh = logging.FileHandler('{0}/run_log.log'.format(dir_name))
ch = logging.StreamHandler()
# 定义handler的输出格式formatter
formatter = logging.Formatter('%(asctime)s %(levelname)s %(lineno)d::%(message)s')
fh.setFormatter(formatter)
ch.setFormatter(formatter)
logger.addHandler(fh)
logger.addHandler(ch)

def getMysqlData(host, port, user, passwd, dbname, query, 
                 dict_ret=False):
    """get data
    Args:
        host: IP地址
        port: 端口
        user: 用户名
        passwd： 密码
        dbname：数据库名称
        query: 执行的语句
        dict_ret: 默认 False
    Returns:
        查询数据库
        默认返回查询结果为嵌套元组；当dict_ret=True，返回结果为列表嵌套字典
    Raises:
        null.
    """
    pool = PooledDB(creator=pymysql, mincached=1, maxcached=20, maxshared=20, 
                    maxconnections=20 ,maxusage=20000, host=host, port=port, 
                    user=user, passwd=passwd, db=dbname, charset="utf8")
    conn = pool.connection()

    # TODO(colin): 嵌套字典与嵌套元组
    if dict_ret:
        cur = conn.cursor(pymysql.cursors.DictCursor)
    else:
        cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()

    return result

def getMysqlConn(host, port, user, passwd, dbname):
    """get mysql connection.
    Args:
        host: IP地址
        port: 端口
        user: 用户名
        passwd： 密码
        dbname：数据库名称
    Returns:
        数据库连接
    Raises:
        null.
    """
    pool = PooledDB(creator=pymysql, mincached=1, maxcached=20, maxshared=20, 
                    maxconnections=20 ,maxusage=20000, host=host, port=port, 
                    user=user, passwd=passwd, db=dbname, charset="utf8")
    conn = pool.connection()

    return conn

def getServerList(sid):
    """get game server DB info.
    Args:
        sid: game server real sid.
    Returns:
        数据库连接地址，元组
    Raises:
        null.
    """
    query = ''' SELECT DISTINCT sdbip,sdbport,sdbname FROM t_gameserver_list 
                WHERE real_sid={0}; '''.format(sid)
    q_ret = getMysqlData(dbhost, dbport, dbuser, dbpasswd, 'Login', query)
    
    return q_ret[0]

if __name__ == '__main__':
    # VIP按等级分组，统计玩家在不同付费点消耗的宝石次数统计
    """
    d_src_type = {0:'无', 1:'升级技能', 2:'修炼', 3:'清除CD', 4:'购买精力', 
                5:'升级阵法', 6:'升级经脉', 7:'复活', 8:'合成', 9:'招募侠客', 
                10:'帮派（天决楼）', 11:'学习被动技能', 12:'兑换', 13:'扫荡', 
                14:'商城', 15:'NPC商店', 16:'购买背包', 17:'帮派战购买', 
                18:'请求购买商城物品', 19:'重置天赋', 20:'侠客堂抽卡', 
                21:'杀手堂抽卡', 22:'寻宝', 23:'拍卖手续费', 24:'拍卖行购买', 
                25:'解绑', 26:'创建联盟', 27:'清除经脉', 28:'修改角色名字', 
                29:'修改联盟名字', 30:'强化', 31:'突破', 32:'天天好礼送不停', 
                33:'联盟击鼓', 34:'联盟宴请', 35:'捐献', 36:'强化联盟地盘', 
                37:'购买拍卖行物品', 38:'开箱子', 39:'开箱子，再来一次', 
                40:'温泉使用物品', 41:'玉门关再来一次花费', 42:'传奇装备', 
                43:'购买VIP商店物品', 44:'野外boss被杀', 45:'拜将台', 
                46:'江湖见闻', 47:'竞技场购买次数', 48:'喂养坐骑祈福', 
                49:'跨服传音', 50:'飞升', 51:'跨服瓦剌重生', 52:'充值抽奖', 
                53:'结婚消耗', 54:'离婚消耗', 55:'归隐侠客', 56:'赛马场', 
                57:'坐骑装备打造', 58:'月签到补签', 59:'跨服联盟战玩家传送/复活消耗', 
                60:'奖励找回', 61:'转职', 62:'多人竞技场购买次数', 
                63:'多人竞技场强制离队', 64:'多人竞技场传音', 65:'联盟商店', 
                66:'高级跨服瓦拉', 67:'心法遗忘', 68:'结拜踢出玩家', 
                69:'跨服擂台赛押注', 70:'跨服擂台赛传音消耗', 71:'结拜改名', 
                72:'云游猜拳改命', 73:'联盟换酒', 74:'PVP洗点', 
                75:'一键扫荡联盟任务'}

    query = ''' SELECT DISTINCT LogicServerID, uid, cid, src_type FROM 
                OSSReduceCash WHERE cashtype1=2 AND insertime BETWEEN 
                '2017-05-03 00:00:00' AND '2017-05-10 23:59:59';'''
    q_ret = getMysqlData('10.225.6.185', 3307, dbuser, dbpasswd, 
                         'OSS_record', query)
    logger.info('从数据库oss_record库提取明细数据完成')

    conn = getMysqlConn(dbhost, dbport, dbuser, dbpasswd, 'Login')
    cur = conn.cursor()
    temp_ret = []
    for i, item in enumerate(q_ret):
        lsid, uid, cid, src_type = item
        query = ''' SELECT DISTINCT real_sid,sdbip,sdbport,sdbname FROM 
                    t_gameserver_list WHERE sid={0}; '''.format(lsid)
        cur.execute(query)
        real_sid, sdbip, sdbport, sdbname = cur.fetchone()
        temp_ret.append([real_sid, uid, cid, src_type])

    cur.close()
    conn.close()
    logger.info('匹配每条信息的real_sid完成')

    players = {}
    for sid, uid, cid, src_type in temp_ret:
        if sid not in players.keys(): players[sid] = []
        players[sid].append([uid, cid, src_type])

    logger.info('按游戏服分组查询玩家的vip数据')
    viplevels = {}
    for sid in players.keys():
        host, port, dbname = getServerList(sid)
        conn = getMysqlConn(host, port, dbuser, dbpasswd, dbname)
        cur = conn.cursor()
        for uid, cid, src_type in players[sid]:
            query = ''' SELECT c_vip_data FROM t_char_vip WHERE 
                        c_cid={0};'''.format(cid)
            cur.execute(query)
            q_ret = cur.fetchone()
            if q_ret:
                t_viplevel = q_ret[0]
                try:
                    gsMsgPb.ParseFromString(t_viplevel)
                    viplevel = int(gsMsgPb.VIPLevel)
                except Exception:
                    viplevel = 0
                if viplevel not in viplevels.keys(): 
                    viplevels[viplevel] = []
                viplevels[viplevel].append(src_type)
        logger.info('{0},{1},{2},{3}'.format(sid, host, port, dbname))

    ret = {}
    for vip in viplevels.keys():
        if vip not in ret.keys(): ret[vip] = []
        for item in d_src_type.keys():
            num = viplevels[vip].count(item)
            num_name = d_src_type[item]
            print '{0}:{1}'.format(num_name, num)
            ret[vip].append(num)

    for vip in ret.keys():
        print vip, ret[vip]
    """

    # VIP按等级分组，统计不同vip等级玩家商城购买情况
    query = ''' SELECT DISTINCT serverid, uid, cid, itemid FROM ShopBuy WHERE 
                insertime BETWEEN '2017-05-03 00:00:00' AND '2017-05-10 23:59:59';'''
    q_ret = getMysqlData('10.225.6.185', 3307, dbuser, dbpasswd, 
                         'OSS_record', query)
    logger.info('从数据库oss_record库提取商城购买明细数据，按角色去重完成')
    conn = getMysqlConn(dbhost, dbport, dbuser, dbpasswd, 'Login')
    cur = conn.cursor()
    temp_ret = []
    for i, item in enumerate(q_ret):
        lsid, uid, cid, itemid = item
        query = ''' SELECT DISTINCT real_sid,sdbip,sdbport,sdbname FROM 
                    t_gameserver_list WHERE sid={0}; '''.format(lsid)
        cur.execute(query)
        real_sid, sdbip, sdbport, sdbname = cur.fetchone()
        temp_ret.append([real_sid, uid, cid, itemid])

    cur.close()
    conn.close()
    logger.info('匹配每条信息的real_sid完成')

    players = {}
    for sid, uid, cid, itemid in temp_ret:
        if sid not in players.keys(): players[sid] = []
        players[sid].append([uid, cid, itemid])

    logger.info('按游戏服分组查询玩家的vip数据')
    viplevels = {}
    for sid in players.keys():
        host, port, dbname = getServerList(sid)
        conn = getMysqlConn(host, port, dbuser, dbpasswd, dbname)
        cur = conn.cursor()
        for uid, cid, itemid in players[sid]:
            query = ''' SELECT c_vip_data FROM t_char_vip WHERE 
                        c_cid={0};'''.format(cid)
            cur.execute(query)
            q_ret = cur.fetchone()
            if q_ret:
                t_viplevel = q_ret[0]
                try:
                    gsMsgPb.ParseFromString(t_viplevel)
                    viplevel = int(gsMsgPb.VIPLevel)
                except Exception:
                    viplevel = 0
                if viplevel not in viplevels.keys(): 
                    viplevels[viplevel] = []
                viplevels[viplevel].append(itemid)
        logger.info('{0},{1},{2},{3}'.format(sid, host, port, dbname))

    query = ''' SELECT itemid FROM ShopBuy WHERE insertime BETWEEN 
                '2017-05-03 00:00:00' AND '2017-05-10 23:59:59' GROUP BY itemid;'''
    q_ret = getMysqlData('10.225.6.185', 3307, dbuser, dbpasswd, 
                         'OSS_record', query)
    itemids = [ item[0] for item in q_ret ]
    ret = {}
    for vip in viplevels.keys():
        if vip not in ret.keys(): ret[vip] = []
        for item in itemids:
            num = viplevels[vip].count(item)
            print '{0}:{1}'.format(item, num)
            ret[vip].append(num)

    for vip in ret.keys():
        print vip, ret[vip]

        