#!/usr/bin/env python
# coding:utf-8
# 功能说明：
#+ 1、每日新增角色的登录日志信息分析；按时间排序，取出每一天的第一条与最后一条日志
#+ 2、新增角色在每个任务的领取和完成数量
from __future__ import division
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
gsdb_user = 'root'
gsdb_passwd = '123456'

# 登录服与充值库,lc：login和charge
lc_user = 'root'
lc_passwd = '123456'
lc_host = '10.221.124.144'
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

def get_task_summary(record_db, str_uid, sta_time, end_time):
    '''
    用于计算指定时间段内的任务接收与完成情况汇总表
    返回结果为列表嵌套列表：[[taskid, accept_num, finish_num],[]]
    '''
    dict_ret = {}   # dict_ret = {taskid:[accept, finish]}

    for host, port in record_db:
        # 计算任务接收量
        query = '''SELECT COUNT(*) AS num,taskid FROM TaskAccept WHERE uid IN ({0}) AND
                    DATE_FORMAT(insertime, '%Y-%m-%d') BETWEEN '{1}' AND '{2}' 
                    GROUP BY taskid;'''.format(str_uid, sta_time, end_time)
        ret = query_mysql_result(host, port, gsdb_user, gsdb_passwd, 'OSS_record', query)
        for num, taskid in ret:
            if taskid not in dict_ret.keys():
                dict_ret[taskid] = [num, 0]
            else:
                dict_ret[taskid][0] = dict_ret[taskid][0] + num
        # 计算任务完成量
        query = '''SELECT COUNT(*) AS num,taskid FROM TaskFinish WHERE uid IN ({0}) AND
                    DATE_FORMAT(insertime, '%Y-%m-%d') BETWEEN '{1}' AND '{2}' 
                    GROUP BY taskid;'''.format(str_uid, sta_time, end_time)
        ret = query_mysql_result(host, port, gsdb_user, gsdb_passwd, 'OSS_record', query)
        for num, taskid in ret:
            if taskid not in dict_ret.keys():
                dict_ret[taskid] = [0, num]
            else:
                dict_ret[taskid][1] = dict_ret[taskid][1] + num

    ret = []
    for item in dict_ret.keys():
        ret.append([item, dict_ret[item][0], dict_ret[item][1]])

    return ret

class UserTotalCount(object):
    '''
    用于抽取玩家登录日志，计算等级分布
    新增日期 等级 当日第一次等级分布  当日第二次 次留等级第一次分布 次留第二次 ...
    '''
    def __init__(self, lc_user, lc_passwd):
        super(UserTotalCount, self).__init__()
        self.user = lc_user
        self.passwd = lc_passwd

    def get_new_uid(self):
        '''
        查询新增的uid，通过日期分组
        返回结果为：{date:[uid1,uid2,],}
        '''
        ret = {}
        query = '''SELECT c_uid, DATE_FORMAT(inserttime, '%Y-%m-%d') AS t_date 
                FROM t_account WHERE DATE_FORMAT(inserttime, '%Y-%m-%d') 
                BETWEEN '2017-05-03' AND '2017-05-11';'''
        q_ret = query_mysql_result('10.221.124.144', 3306, self.user, self.passwd, 
                                   'Login', query)
        for uid, date in q_ret:
            if date not in ret.keys():
                ret[date] = [uid]
            else:
                ret[date].append(uid)

        return ret

    def get_gsdb_info(self, sid):
        '''
        获取指定sid的游戏从库连接信息
        返回结果为元组：(sdbip, sdbport, sdbname)
        '''
        query = '''SELECT sdbip, sdbport, sdbname FROM t_gameserver_list WHERE 
                sid = {0};'''.format(sid)
        q_ret = query_mysql_result('10.221.124.144', 3306, self.user, self.passwd, 
                                   'Login', query)
        return q_ret[0]

    def get_max_level(self, t_dict):
        '''
        获取指定uid与cid的当前角色等级
        返回结果为字典:{level1:num1,level2:num2}
        '''
        ret = {}
        for lsid, uid_cid in t_dict.items():
            sdbip, sdbport, sdbname = self.get_gsdb_info(lsid)
            conn = mysql_conn(sdbip, sdbport, self.user, self.passwd, sdbname)
            cur = conn.cursor()
            for uid, cid in uid_cid:
                query = '''SELECT c_level FROM t_char_basic WHERE c_uid = {0} AND 
                        c_cid = {1};'''.format(uid, cid)
                cur.execute(query)
                q_ret = cur.fetchall()
                try:
                    level = q_ret[0][0]
                except Exception:
                    pass
                if level not in ret.keys():
                    ret[level] = 1
                else:
                    ret[level] += 1
            cur.close()
            conn.close()

        return ret

    def get_login_log(self):
        '''
        获取指定uid的登录日志
        返回结果为字典嵌套多重字典：{date:{level1:{0:num0,1:num1,},level2:...}}
        '''
        ret = {}
        dict_uids = self.get_new_uid()
        for date, uids in dict_uids.items():
            logging.info('统计{0}的等级情况'.format(date))
            str_uid = str(uids)[1:-1]
            daytime = time.strptime(date, '%Y-%m-%d')
            dict_ret = {} # {level1:{0A:num0,0B:num0,1A:num0,1B:num0}}
            # 分别对应当日，次日，第3日，第4日
            # 每日取第一次与最后一次
            for day in [0, 1, 2, 3]:
                for item in ['min', 'max']:
                    query = '''SELECT LogicServerID, uid, cid, level FROM Login{0} a 
                            WHERE uid IN ({1}) AND UNIX_TIMESTAMP(insertime) = ( SELECT 
                            {2}(UNIX_TIMESTAMP(insertime)) FROM Login{0} b WHERE 
                            b.uid = a.uid );'''.format(day + daytime.tm_yday, str_uid, item)
                    q_ret = query_mysql_result('10.221.168.131', 3306, self.user, 
                                                self.passwd, 'OSS', query)

                    if item == 'min':
                        t_day = '{0}A'.format(day)
                    elif item == 'max':
                        t_day = '{0}B'.format(day)

                    for _, _, _, level in q_ret:
                        if level not in dict_ret.keys(): dict_ret[level] = {}
                        if t_day not in dict_ret[level].keys(): dict_ret[level][t_day] = 1
                        dict_ret[level][t_day] = dict_ret[level][t_day] + 1

            ret[date] = dict_ret

        logging.info('ALL等级统计汇总完成.')
        return ret

if __name__ == '__main__':
    logging.info('Scripts is running...')
    # 定义需要查询的uid时间范围
    sta_time = '2017-05-03'
    end_time = '2017-05-11'

    query = '''SELECT  c_uid FROM t_account WHERE DATE_FORMAT(inserttime, '%Y-%m-%d') 
            BETWEEN '{0}' AND '{1}';'''.format(sta_time, end_time)
    query_ret = query_mysql_result(lc_host, lc_port, lc_user, lc_passwd, 'Login', query)

    # 任务接收与完成情况统计
    uids = [item[0] for item in query_ret]
    logging.info(uids)
    str_uid = str(uids)[1:-1]   #截取头和尾的[]符号

    record_db = (('10.221.172.123',3306),
                 ('10.221.172.123',3307),
                 ('10.221.76.226',3306),
                 ('10.221.76.226',3307))

    file_name = "result_task_and_old_player.xlsx"
    ret = get_task_summary(record_db, str_uid, sta_time, end_time)
    logging.info('任务数据汇总完成')
    workbook = xlsxwriter.Workbook(file_name)
    worksheet = workbook.add_worksheet('任务接收与完成汇总')
    col_data = [{'header': '任务ID'}, {'header': '接收量'}, {'header': '完成量'}]
    worksheet.set_column(0, len(col_data) - 1, 15)
    tab_addrs = 'A1:{0}{1}'.format(chr(64 + len(col_data)), len(ret) + 1)
    options = {'data': ret,
               'style': 'Table Style Light 11',
               'columns': col_data}
    logging.info(ret)
    worksheet.add_table(tab_addrs, options)
    logging.info('任务数据写入excel完成')

    # 玩家等级分布情况统计
    worksheet = workbook.add_worksheet('留存按等级分布统计')
    tab_lab = ['新增日期','等级','当日F分布','当日L分布','次日F分布','次日L分布',
               '3日F分布','3日L分布','4日F分布','4日L分布']
    for i, item in enumerate(tab_lab):
        worksheet.write(0, i, item)

    testa = UserTotalCount(lc_user, lc_passwd)
    t_date = testa.get_login_log()
    j = 1
    for date, dict_level in t_date.items():
        for i in range(61):
            l_info = dict_level.get(i)
            if l_info:
                data = [date, i, 
                        l_info.get('0A', 0), l_info.get('0B', 0),
                        l_info.get('1A', 0), l_info.get('1B', 0), 
                        l_info.get('2A', 0), l_info.get('2B', 0),
                        l_info.get('3A', 0), l_info.get('3B', 0)]
            else:
                data = [date, i]
            for x, item in enumerate(data):
                worksheet.write(j, x, item)

            j += 1

    logging.info('等级分布数据写入excel完成.')

    workbook.close()
    print 'Result in file: ./{0}'.format(file_name)
