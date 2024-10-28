#!/usr/bin/env python
#coding=utf-8
# 按角色统计，截止到5月10日时，每日新增玩家不同充值金额玩家留存
#################################
# 需求分解
# 1、统计指定日期新增的 uid 清单
# 2、根据新增的uid清单，查找充值库中，符合这些uid的玩家充值数据并汇总为：
#+   sid, uid, cid, totalmoney
# 3、根据汇总的玩家充值数据，查询这些玩家的登录日志行为，判断其流失情况
# 4、然后把【1、2、3】作为整体从4月1日循环处理到5月10日。
#################################

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
        数据库连接地址，嵌套元组 ((),()...)
    Raises:
        null.
    """
    query = ''' SELECT DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname FROM 
                t_gameserver_list WHERE real_sid={0}; '''.format(sid)
    q_ret = getMysqlData(dbhost, dbport, dbuser, dbpasswd, 'Login', query)
    
    return q_ret

def getOSSRecordDB(date):
    """ 根据日期参数，获取该日期用的是那一个oss_record库
    Args:
        date: 日期，格式为： 2017-05-03
    Returns:
        数据库连接地址，返回结果为元组
    Raises:
        null
    """
    weekid = time.strftime('%W', time.strptime(date, "%Y-%m-%d"))
    query = ''' SELECT slave_ip,slave_port,slave_dbname FROM t_ossdb_list WHERE 
                week_id={0}; '''.format(weekid)
    q_ret = getMysqlData('iamIPaddress', 3306, dbuser, dbpasswd, 'OSS', query)

    return q_ret[0]

def getNewUidList(date):
    """ 根据日期参数，获取当日新增的uid清单
    Args:
        date: 日期，格式为： 2017-05-03
    Returns:
        返回结果为元组(1, 2, 3, ...) ，新增的uid清单
    Raises:
        null
    """
    query = ''' SELECT c_uid FROM t_account WHERE inserttime BETWEEN 
                '{0} 00:00:00' AND '{0} 23:59:59'; '''.format(date)
    q_ret = getMysqlData(dbhost, dbport, dbuser, dbpasswd, 'Login', query)
    uidlists = tuple([item[0] for item in q_ret])

    return uidlists

def getChargeList(stime, etime, uidlists):
    """ 获取充值金额分类的玩家清单
    Args:
        stime: 开始日期，格式为： 2017-05-03
        etime: 结束日期，格式同stime
        uidlists：新增的uid清单，元组，函数getNewUidList的返回值
    Returns:
        返回结果为字典 chargesort，见字典chargesort定义
    Raises:
        null
    """
    query = ''' SELECT sid, uid, cid, sum(totalmoney) AS tmoney 
                FROM IOSFinish WHERE time BETWEEN '{0} 00:00:00' AND 
                '{1} 00:00:00' AND uid in {2} GROUP BY sid, uid, 
                cid;'''.format(stime, etime, str(uidlists))
    q_ret = getMysqlData(dbhost, dbport, dbuser, dbpasswd, 'Charge', query)

    chargesort = {
        '0_5':[],
        '6_11':[],
        '12_30':[],
        '31_50':[],
        '51_100':[],
        '101_200':[],
        '201_300':[],
        '301_500':[],
        '501_1000':[],
        '1001_3000':[],
        '3001_5000':[],
        '5001_10000':[],
        '10001':[]
    }
    for sid, uid, cid, tmoney in q_ret:
        if tmoney <= 5:
            chargesort['0_5'].append([sid, uid, cid])
        elif tmoney <= 11:
            chargesort['6_11'].append([sid, uid, cid])
        elif tmoney <= 30:
            chargesort['12_30'].append([sid, uid, cid])
        elif tmoney <= 50:
            chargesort['31_50'].append([sid, uid, cid])
        elif tmoney <= 100:
            chargesort['51_100'].append([sid, uid, cid])
        elif tmoney <= 200:
            chargesort['101_200'].append([sid, uid, cid])
        elif tmoney <= 300:
            chargesort['201_300'].append([sid, uid, cid])
        elif tmoney <= 500:
            chargesort['301_500'].append([sid, uid, cid])
        elif tmoney <= 1000:
            chargesort['501_1000'].append([sid, uid, cid])
        elif tmoney <= 3000:
            chargesort['1001_3000'].append([sid, uid, cid])
        elif tmoney <= 5000:
            chargesort['3001_5000'].append([sid, uid, cid])
        elif tmoney <= 10000:
            chargesort['5001_10000'].append([sid, uid, cid])
        else:
            chargesort['10001'].append([sid, uid, cid])

    return chargesort

if __name__ == '__main__':

    stime = '2017-04-01'
    etime = '2017-05-10'

    conn = getMysqlConn('iamIPaddress', 3306, dbuser, dbpasswd, 'OSS')
    cur = conn.cursor()

    strtime = datetime.datetime.strptime(stime, '%Y-%m-%d')
    endtime = datetime.datetime.strptime(etime, '%Y-%m-%d')
    days = endtime.utctimetuple().tm_yday - strtime.utctimetuple().tm_yday + 1

    for dd_day in range(days):
        frist_day = strtime + datetime.timedelta(days = dd_day)
        date = frist_day.strftime("%Y-%m-%d")

        logger.info('开始查询指定期间的新增帐号')
        uidlists = getNewUidList(date)
        logger.info('已查询到新增的uid清单')

        chargesort = getChargeList(date, etime, uidlists)
        for key in chargesort.keys():
            uids = chargesort.get(key, 0)
            login_count = []
            if uids:
                num = len(uids)
                for i in range(1, 30):
                    login_num = 0
                    day = frist_day.utctimetuple().tm_yday + i
                    for sid ,uid ,cid in uids:
                        query = ''' SELECT serverid, uid, cid FROM Login{3} WHERE 
                                    serverid = {0} AND uid = {1} AND 
                                    cid = {2};'''.format(sid, uid, cid, day)
                        cur.execute(query)
                        q_ret = cur.fetchall()
                        if q_ret: login_num += 1

                    login_count.append(login_num)
            else:
                num = 0

            logger.info('{0}\t{1}\t{2}\t{3}'.format(date, key, num, login_count)) 

    cur.close()
    conn.close()

    