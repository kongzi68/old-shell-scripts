#!/usr/bin/env python
#coding=utf-8
# 统计第一天有登陆但第二日未登陆和第二日有活跃但第三日未登陆角色等级和任务情况

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
    """ 根据日期参数，获取该日志用的是那一个oss_record库
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


def getLosePlayers(date, uidlists):
    """ 查指定日期的登录日志，抽取流失玩家的信息
    Args:
        date: 日期，格式为: '2017-05-03'
        uidlists: 元组，date所指定日期新增的uid
    Returns:
        返回结果类似：{'d1':[], 'd2':[]}
        为第二、三天以第一天为基准的UID找出的流失玩家UID数据
    """
    ret = {'d1':[], 'd2':[]}
    d_stime = time.strptime(date, "%Y-%m-%d")
    day = d_stime.tm_yday

    # 查第一天的数据
    query = ''' SELECT DISTINCT serverid, uid, cid FROM Login{0} WHERE uid in 
                {1} GROUP BY serverid, uid, cid; '''.format(day, uidlists)
    q_ret = getMysqlData('iamIPaddress', 3306, dbuser, dbpasswd, 'OSS', query)

    # 查第二、三天的数据
    conn = getMysqlConn('iamIPaddress', 3306, dbuser, dbpasswd, 'OSS')
    cur = conn.cursor()
    for serverid, uid, cid in q_ret:
        for i in range(1, 3):
            query = ''' SELECT uid, cid FROM Login{0} WHERE uid = {1} AND 
                        cid = {2}; '''.format(day + i, uid, cid)
            cur.execute(query)
            q_ret = cur.fetchall()
            if not q_ret:
                if i == 1:
                    ret['d1'].append([serverid, uid, cid])
                else:
                    ret['d2'].append([serverid, uid, cid])

    cur.close()
    conn.close()
    return ret

def countLosePlayers(date, d_playinfo):
    """ 根据传入的字典，计算玩家的等级分布
        处理函数getLosePlayers返回来的数据
    Args:
        d_playinfo: 格式为：{'d1':[], 'd2':[]}
    Returns:
        返回结果类似：{'d1':{level1:5,level2:7,level3:1},'d2':{}}
        计算流失玩家的等级分布
    """
    ret = {'d1':{},'d2':{}}

    d_stime = time.strptime(date, "%Y-%m-%d")
    day = d_stime.tm_yday
    
    conn = getMysqlConn('iamIPaddress', 3306, dbuser, dbpasswd, 'OSS')
    cur = conn.cursor()

    for i in range(1, 3):
        key = 'd{0}'.format(i)
        for serverid, uid, cid in d_playinfo[key]:
            query = ''' SELECT level FROM Login{0} WHERE uid={1} AND cid={2} 
                        AND serverid={3};'''.format(day + i - 1, uid, cid, serverid)
            cur.execute(query)
            q_ret = cur.fetchall()
            if q_ret:
                level = q_ret[0][0]
                # 这一段省掉了一个函数，以前咋没想到？哈哈
                if level not in ret[key].keys(): 
                    ret[key][level] = 1
                else:
                    ret[key][level] += 1 

    return ret


if __name__ == '__main__':

    stime = '2017-05-03'
    etime = '2017-05-10'

    logger.info('开始查询指定期间的新增帐号')
    query = ''' SELECT c_uid FROM t_account WHERE inserttime BETWEEN 
                '{0} 08:00:00' AND '{1} 23:59:59'; '''.format(stime, etime)
    q_ret = getMysqlData(dbhost, dbport, dbuser, dbpasswd, 'Login', query)
    uidlists = tuple([item[0] for item in q_ret])
    logger.info('已查询到新增的uid清单')

    loseplayer = {}
    loseplayertask = {} # 流失玩家的sid，uid，cid清单
    for i in range(4, 11):
        t_date = '2017-5-{0}'.format(i)
        logger.info('{0}: 玩家流失数据已处理'.format(t_date))
        one_day_players = getLosePlayers(t_date, uidlists)
        one_day = countLosePlayers(t_date, one_day_players)
        if t_date not in loseplayer.keys():
            loseplayer[t_date] = one_day
        if t_date not in loseplayertask.keys():
            loseplayertask[t_date] = one_day_players

    '''
    for item in loseplayer.keys():
        for ditem in loseplayer[item].keys():
            for level in range(1, 61):
                level_num = loseplayer[item][ditem].get(level, 0)
                print '{0}\t{1}\t{2}\t{3}'.format(item, level, ditem, level_num)
                # TODO(colin): 太难写了，注释掉的功能未完成，改用打印后在excel里面粘贴
                # data = (item, level, ditem, level_num)
    '''

    logger.info('开始统计流失玩家的任务完成情况')
    d_taskid = {}  # 用于存储任务情况分布的字典
    for item in loseplayertask.keys():
        host, port, dbname = getOSSRecordDB(item)
        conn = getMysqlConn(host, port, dbuser, dbpasswd, dbname)
        cur = conn.cursor()
        if item not in d_taskid.keys(): d_taskid[item] = {}
        for ditem in loseplayertask[item].keys():
            if ditem not in d_taskid[item].keys(): d_taskid[item][ditem] = {}
            for sid, uid, cid in loseplayertask[item][ditem]:
                logger.info('{0},{1},{2}'.format(sid, uid, cid))
                query = ''' SELECT taskid FROM TaskFinish WHERE serverid={0} 
                            AND uid={1} AND cid={2} AND insertime BETWEEN 
                            '{3} 08:00:00' AND '{4} 23:59:59'; '''.format(
                                sid, uid, cid, stime, etime)
                cur.execute(query)
                q_ret = cur.fetchall()
                if q_ret:
                    for taskid in q_ret:
                        if taskid not in d_taskid[item][ditem].keys():
                            d_taskid[item][ditem][taskid] = 1
                        else:
                            d_taskid[item][ditem][taskid] += 1
                    logger.info('{0}'.format(q_ret))
        cur.close()
        conn.close()

    # task_count = {'2017-05-03':{'10011045':{d1:d1_num, d2:d2_num}}}
    task_count = {}
    logger.info('流失玩家任务完成情况分布统计完成')
    for item in d_taskid.keys():
        if item not in task_count.keys(): task_count[item] = {}
        for ditem in d_taskid[item].keys():
            for taskid in d_taskid[item][ditem].keys():
                taskid_num = d_taskid[item][ditem][taskid]
                if taskid not in task_count[item].keys():
                    task_count[item][taskid] = {}
                task_count[item][taskid][ditem] = taskid_num
                # print '{0}\t{1}\t{2}'.format(item, taskid, ditem, taskid_num)

    for item in task_count.keys():
        for taskid in task_count[item].keys():
            d1 = task_count[item][taskid].get('d1', 0)
            d2 = task_count[item][taskid].get('d2', 0)
            logger.info('{0}:{1}:{2}:{3}'.format(item, taskid, d1, d2))
            