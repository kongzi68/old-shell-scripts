#!/usr/bin/env python
# coding:utf-8
# 功能说明：
#   抽取新服的t_char_basic里面的数据
# 定时计划
##  抽取223服在2月23日创建角色的玩家，导出其连续几天的登出时间数据
##  5 0 23-28 * * python /data/scripts/vip/work/send_t_char_basic.py >> /tmp/cron.log 2>&1 & 

import pymysql
import xlsxwriter
import time
import logging

# 导入mysql连接池管理
from DBUtils.PooledDB import PooledDB

import sys
reload(sys)
sys.setdefaultencoding("utf8")

# 定义log日志格式
logger = logging.getLogger()
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
# 定义handler的输出格式formatter
formatter = logging.Formatter('%(asctime)s %(levelname)s [line:%(lineno)d]:: %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

# 游戏服用户名与密码
gsdb_user = 'IamUsername'
gsdb_passwd = '123456'

# 登录服与充值库,lc：login和charge
lc_user = 'IamUsername'
lc_passwd = '123456'
lc_host = 'iamIPaddress'
lc_port = 3306

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

if __name__ == '__main__':

    logging.info("Now, export t_char_basic.")
    query = '''SELECT c_uid,c_cid,c_charname,c_level,FROM_UNIXTIME(c_last_leave_time) 
               AS last_leave_time FROM t_char_basic WHERE DATE_FORMAT(c_create_time,'%Y-%m-%d') = '2017-02-23';'''
    q_ret = query_mysql_result('iamIPaddress', 3307, gsdb_user, gsdb_passwd, 
                               'ProjectM', query)

    # 创建excle表格文件，保存匹配的数据
    file_name = "t_char_basic,{0}.xlsx".format(time.strftime("%Y_%m_%d", time.localtime()))
    workbook = xlsxwriter.Workbook(file_name)
    tformat = workbook.add_format()
    tformat.set_num_format('yyyy/mm/dd hh:mm:ss')
    worksheet = workbook.add_worksheet('新增玩家等级信息追踪')
    col_data = [{'header': 'uid'}, {'header': 'cid'}, {'header': '角色名'}, {'header': 'level'}, 
                {'header': 'last_leave_time', 'format': tformat}]
    worksheet.set_column(0, len(col_data) - 1, 15)
    tab_addrs = 'A1:{0}{1}'.format(chr(64 + len(col_data)), len(q_ret) + 1)
    options = {'data': q_ret,
               'style': 'Table Style Light 11',
               'columns': col_data}
    worksheet.add_table(tab_addrs, options)

    workbook.close()
    logging.info("Result in file: ./{0}".format(file_name))


