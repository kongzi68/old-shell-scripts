#!/usr/bin/env python
# coding:utf-8
# 功能说明：
#+ 1、用于查询充值流水记录，发给财务的
#+ 规格为: 订单号，金额，时间
import pymysql
import xlsxwriter
import time
import logging
import os
import sys

# 导入mysql连接池管理
from DBUtils.PooledDB import PooledDB

reload(sys)
sys.setdefaultencoding("utf8")

#--------------------------
# 定义脚本部署所在的国家，可用国家值为：china、korea、thailand、vietnam
# 可以在字典table_name中进行定义添加其它国家
country = 'china'

# 定义查周记录还是月记录，可用值为：monthly、weekly
q_type = 'weekly'

# 充值库:charge
ch_user = 'IamUsername'
ch_passwd = '123456'
ch_host = 'iamIPaddress'
ch_port = 3306
#--------------------------

# 定义字典，格式为：{国家: {表名1: [字段11, 字段12, 字段13], [...]},{...}}
table_name = {
    china: {
        IOSFinish: [transaction_id, totalmoney, time],
        TmallFinish: [transaction_id, totalmoney, time]
        },
    korea: {
        nexonfinish: [transaction_id, totalmoney, time],
        iosfinish: [transaction_id, totalmoney, time]
        },
    thailand: {
        nexonfinish: [transaction_id, totalmoney, time],
        iosfinish: [transaction_id, totalmoney, time]
        },
    vietnam: {
        nexonfinish: [transaction_id, totalmoney, time],
        iosfinish: [transaction_id, totalmoney, time]
        }
}

dir_name, _ = os.path.split(os.path.abspath(sys.argv[0]))

# 定义log日志格式
logger = logging.getLogger()
logger.setLevel(logging.INFO)
fh = logging.FileHandler('{0}/run_log.log'.format(dir_name))
ch = logging.StreamHandler()
# 定义handler的输出格式formatter
formatter = logging.Formatter('%(asctime)s %(levelname)s [line:%(lineno)d]:: %(message)s')
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




    