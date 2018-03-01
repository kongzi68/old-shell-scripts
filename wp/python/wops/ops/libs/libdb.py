# coding=utf-8
import ConfigParser
import pymysql
from DBUtils.PooledDB import PooledDB

# 读取DB配置文件
cf = ConfigParser.ConfigParser()
cf.read('config/config.conf')
# cmdb配置
cmdb_host = cf.get('cmdb', 'host')
cmdb_port = cf.getint('cmdb', 'port')
cmdb_dbname = cf.get('cmdb', 'dbname')
cmdb_user = cf.get('cmdb', 'user')
cmdb_passwd = cf.get('cmdb', 'passwd')
cmdb = {
    'host': cmdb_host,
    'port': cmdb_port,
    'dbname': cmdb_dbname,
    'user': cmdb_user,
    'passwd': cmdb_passwd
}
# cmdb_oss配置
cmdb_oss_host = cf.get('cmdb_oss', 'host')
cmdb_oss_port = cf.getint('cmdb_oss', 'port')
cmdb_oss_dbname = cf.get('cmdb_oss', 'dbname')
cmdb_oss_user = cf.get('cmdb_oss', 'user')
cmdb_oss_passwd = cf.get('cmdb_oss', 'passwd')
cmdb_oss = {
    'host': cmdb_oss_host,
    'port': cmdb_oss_port,
    'dbname': cmdb_oss_dbname,
    'user': cmdb_oss_user,
    'passwd': cmdb_oss_passwd
}

# cmdb_web配置
cmdb_web_host = cf.get('cmdb_web', 'host')
cmdb_web_port = cf.getint('cmdb_web', 'port')
cmdb_web_dbname = cf.get('cmdb_web', 'dbname')
cmdb_web_user = cf.get('cmdb_web', 'user')
cmdb_web_passwd = cf.get('cmdb_web', 'passwd')
cmdb_web = {
    'host': cmdb_web_host,
    'port': cmdb_web_port,
    'dbname': cmdb_web_dbname,
    'user': cmdb_web_user,
    'passwd': cmdb_web_passwd
}

# 默认使用CMDB库的配置
def getMysqlData(host=cmdb_host, port=cmdb_port, user=cmdb_user, passwd=cmdb_passwd, dbname=cmdb_dbname, query=None,
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
    if query is None: return
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

def getMysqlConn(host=cmdb_host, port=cmdb_port, user=cmdb_user, passwd=cmdb_passwd, dbname=cmdb_dbname):
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

