#!/usr/bin/env python
#coding=utf-8
# 查询[付费]玩家等级分布情况
# 结果为：等级，服务器1，服务器2, ...
from DBUtils.PooledDB import PooledDB
import pymysql
import xlsxwriter
import time
import logging, os
import sys
reload(sys)
sys.setdefaultencoding("utf-8")

#--------------------------
dbuser = 'root'
dbpasswd = '123456'
dbhost = '10.66.143.17'
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

def open_gs_date(host, port, dbname):
    '''
    查询开服时间，返回结果格式为：2017-04-05
    '''
    query = ''' SELECT DATE_FORMAT(c_create_time, '%Y-%m-%d') AS ctime, 
                COUNT( DATE_FORMAT(c_create_time, '%Y-%m-%d')) AS num 
                FROM t_char_basic GROUP BY ctime HAVING num > 10 
                ORDER BY ctime LIMIT 1; '''
    ret_query = query_mysql_result(host, port, dbuser, dbpasswd, dbname, 
                                   query, dict_ret=True)
    return ret_query[0]['ctime']

if __name__ == '__main__':

    dict_ret = {}

    # 查询充值过的玩家清单
    query = "SELECT DISTINCT sid, uid, cid FROM SpecialFinish;"
    q_ret = query_mysql_result(dbhost, dbport, dbuser, 
                               dbpasswd, 'Charge', query)
    dict_charge = {}
    for sid, uid, cid in q_ret:
        if sid not in dict_charge.keys(): dict_charge[sid] = []
        dict_charge[sid].append([uid, cid])
    logger.info("get charge list finish.")

    for sid in dict_charge.keys():
        try:
            gsdbip, gsdbport, gsdbname, _, gssname = getServerList(sid)[0]
            logger.info('{0}'.format(gssname))
        except Exception:
            continue

        # 查玩家1-60普通等级
        opendate = time.strptime(open_gs_date(gsdbip, gsdbport, 
            gsdbname), '%Y-%m-%d')
        query = ''' SELECT DISTINCT uid, cid, level, max(insertime) AS maxtime 
                    FROM Login{0} WHERE serverid={1} GROUP BY serverid, uid, 
                    cid; '''.format(opendate.tm_yday, sid)
        q_ret = query_mysql_result('10.66.203.128', 3306, dbuser, 
                                    dbpasswd, 'OSS', query)
        t_dict_level = {}
        for uid, cid, tlevel, _ in q_ret:
            if [uid, cid] in dict_charge[sid]:
                tlevel = 't{0}'.format(tlevel)
                if tlevel not in t_dict_level.keys(): t_dict_level[tlevel] = []
                t_dict_level[tlevel].append(1) # 如果是充值玩家，该等级添加一个元素
        # logger.info('{0}'.format(t_dict_level))

        # 查玩家1-400破镜等级
        p_dict_level = {}
        conn = mysql_conn(gsdbip, gsdbport, dbuser, dbpasswd, gsdbname)
        cur = conn.cursor()
        for _, cid in dict_charge[sid]:
            query = ''' SELECT c_addition_level FROM t_char_newdata WHERE  
                        c_cid={0}; '''.format(cid)
            cur.execute(query)
            try:
                plevel = 'p{0}'.format(cur.fetchone()[0])
                if plevel not in p_dict_level.keys(): p_dict_level[plevel] = []
                p_dict_level[plevel].append(1)
            except Exception:
                continue
        # logger.info('{0}'.format(p_dict_level)) 

        # 汇总该游戏服的等级分布
        temp_dict = dict(t_dict_level, **p_dict_level)
        for item in temp_dict.keys():
            if gssname not in dict_ret.keys(): dict_ret[gssname] = {}
            dict_ret[gssname][item] = len(temp_dict.get(item))
        logger.info('{0}'.format(dict_ret[gssname]))

        cur.close()
        conn.close()

    #============================
    # 把结果写入excel表格
    fileName="result.xlsx"
    workbook=xlsxwriter.Workbook(fileName)
    t_format = workbook.add_format({'bold': True})
    t_format.set_align('center')
    t_format.set_align('vcenter')
    worksheet = workbook.add_worksheet("sheet1")
    worksheet.set_column(0, 10, 12)
    worksheet.write(0, 0, '等级', t_format)   # 写列与行交叉的标题
    # 写竖向标题
    for j in range(1, 61):
        worksheet.write(j, 0, 't{0}'.format(j), t_format)
    for j in range(1, 401):
        worksheet.write(j+60, 0, 'p{0}'.format(j), t_format)

    # 写数据
    for i, item in enumerate(dict_ret.keys()):
        worksheet.write(0, i+1, item, t_format) # 写列标题
        for j in range(1, 461):
            if j < 61:
                key = 't{0}'.format(j)
            else:
                key = 'p{0}'.format(j - 60)
            t_date = dict_ret[item].get(key, 0)
            # logger.info('{0},{1},{2}'.format(i,j,t_date))
            worksheet.write(j, i+1, t_date)

    workbook.close()
    logger.info('Result in file: {0}, done.'.format(fileName))

