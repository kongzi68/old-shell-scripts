#!/usr/bin/env python
#coding=utf-8
# 查询付费玩家使用某道具的比例
# 结果为：付费玩家数量，使用某物品的玩家数量，占比多少
from __future__ import division  # 为相除结果为浮点数 
from DBUtils.PooledDB import PooledDB
import pymysql
import xlsxwriter
import logging, os
import sys
reload(sys)
sys.setdefaultencoding("utf-8")

#--------------------------
dbuser = 'IamUsername'
dbpasswd = '123456'
dbhost = 'iamIPaddress'
dbport = 3306
#--------------------------

# 定义log日志格式
logger = logging.getLogger()
logger.setLevel(logging.INFO)
dir_name, _ = os.path.split(os.path.abspath(sys.argv[0]))
fh = logging.FileHandler('{0}/run_log.log'.format(dir_name))
ch = logging.StreamHandler()
# 定义handler的输出格式formatter
formatter = logging.Formatter('%(asctime)s %(levelname)s %(lineno)d %(message)s')
fh.setFormatter(formatter)
ch.setFormatter(formatter)
logger.addHandler(fh)
logger.addHandler(ch)

def query_mysql_result(host, port, user, passwd, dbname, query, 
                       dict_ret=False):
    '''
    查询数据库
    默认返回查询结果为嵌套元组；当dict_ret=True，返回结果为列表嵌套字典
    '''
    pool = PooledDB(creator=pymysql, mincached=1, maxcached=20, maxshared=20, 
                    maxconnections=20 ,maxusage=20000, host=host, port=port, 
                    user=user, passwd=passwd, db=dbname, charset="utf8")
    conn = pool.connection()

    if dict_ret:
        cur = conn.cursor(pymysql.cursors.DictCursor)
    else:
        cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()
    cur.close()
    conn.close()

    return result

def mysql_conn(host, port, user, passwd, dbname):
    '''
    返回连接
    '''
    pool = PooledDB(creator=pymysql, mincached=1, maxcached=20, maxshared=20, 
                    maxconnections=20 ,maxusage=20000, host=host, port=port, 
                    user=user, passwd=passwd, db=dbname, charset="utf8")
    conn = pool.connection()

    return conn

def getServerList(sid):
    '''
    拉取所有游戏服数据库信息
    返回：嵌套元组 ((),()...)
    '''
    query = '''SELECT DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname FROM 
            t_gameserver_list WHERE real_sid={0};'''.format(sid)
    server_list = query_mysql_result(dbhost, dbport, dbuser, 
                                     dbpasswd, 'Login', query)
    return server_list

if __name__ == '__main__':

    dict_result = {}

    # 查询充值过的玩家清单
    query = "SELECT DISTINCT sid, uid, cid FROM SpecialFinish;"
    q_ret = query_mysql_result(dbhost, dbport, dbuser, 
                               dbpasswd, 'Charge', query)
    dict_charge = {}
    for sid, uid, cid in q_ret:
        if sid not in dict_charge.keys(): dict_charge[sid] = []
        dict_charge[sid].append([uid, cid])
    logger.info("get charge list finish.")

    # 统计充值玩家与这些玩家物品使用相关的数据
    conn = mysql_conn('iamIPaddress', 3306, dbuser, dbpasswd, 'OSS_record')
    cur = conn.cursor()
    for sid in dict_charge.keys():
        if sid not in dict_result.keys(): dict_result[sid] = []
        # 获取游戏服名称
        try:
            _, _, _, _, rsname = getServerList(sid)[0]
        except Exception:
            continue
        dict_result[sid].append(rsname)
        logger.info('开始计算游戏服：{0}'.format(rsname))

        # 计算每个游戏服的充值玩家数量
        c_num = len(dict_charge[sid])
        dict_result[sid].append(c_num)
        logger.info('该游戏服充值玩家数量为：{0}'.format(c_num))

        # 计算每个游戏服的充值玩家使用某物品的数量
        num = 0
        for uid, cid in dict_charge[sid]:
            query = '''SELECT uid, cid FROM RemoveItem WHERE itemid=15195099 AND
                    serverid={0} AND uid={1} AND cid={2};'''.format(sid, uid, cid)
            q_ret = cur.execute(query)
            if q_ret: num += 1
        dict_result[sid].append(num)
        logger.info('该游戏服充值玩家使用指定道具的数量为：{0}'.format(num))

        # 计算占比
        dict_result[sid].append('{0}'.format(num / c_num, '.2%'))

    cur.close()
    conn.close()

    # 把结果写入excel表格
    ret = dict_result.values()
    logger.info('{0}'.format(ret))
    fileName = "querydaojiu.xlsx"
    workbook = xlsxwriter.Workbook(fileName)
    worksheet = workbook.add_worksheet("sheet1")
    col_data = [{'header': '游戏服'}, {'header': '充值玩家数'}, 
                {'header': '使用经验丹玩家数'}, {'header': '占比'},]
    worksheet.set_column(0, len(col_data) - 1, 15)
    tab_addrs = 'A1:{0}{1}'.format(chr(64 + len(col_data)), len(ret) + 1)
    options = {'data': ret,
               'style': 'Table Style Light 11',
               'columns': col_data}
    worksheet.add_table(tab_addrs, options)
    workbook.close()
    logger.info('done.')