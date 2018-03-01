# coding=utf-8
import ConfigParser
import pymysql
from DBUtils.PooledDB import PooledDB

# 读取DB配置文件
cf = ConfigParser.ConfigParser()
cf.read('swamp/config/config.conf')
# swamp库配置
swamp_host = cf.get('swamp', 'host')
swamp_port = cf.getint('swamp', 'port')
swamp_dbname = cf.get('swamp', 'dbname')
swamp_user = cf.get('swamp', 'user')
swamp_passwd = cf.get('swamp', 'passwd')
swamp = {
    'host': swamp_host,
    'port': swamp_port,
    'dbname': swamp_dbname,
    'user': swamp_user,
    'passwd': swamp_passwd
}


# 默认使用CMDB库的配置
def getMysqlData(host=swamp_host, port=swamp_port, user=swamp_user, passwd=swamp_passwd, dbname=swamp_dbname, query=None,
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

def getMysqlConn(host=swamp_host, port=swamp_port, user=swamp_user, passwd=swamp_passwd, dbname=swamp_dbname):
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

