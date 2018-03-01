# coding=utf-8
import ConfigParser
import pymysql
from DBUtils.PooledDB import PooledDB

# 读取DB配置文件
cf = ConfigParser.ConfigParser()
cf.read('config/cmdb.conf')
host = cf.get('cmdb', 'host')
port = cf.getint('cmdb', 'port')
dbname = cf.get('cmdb', 'dbname')
user = cf.get('cmdb', 'user')
passwd = cf.get('cmdb', 'passwd')
game_type = cf.get('config', 'game_type')

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

def getGameType():
    """
    # 获取游戏ID类型，比如三剑豪国内IOS，三剑豪越南，三剑豪泰国等
    :return:
    """
    ret = False
    query = "SELECT game_id, game, `type` FROM t_gametype;"
    q_ret = getMysqlData(host, port, user, passwd, dbname, query)
    for gameid, game, t_type in q_ret:
        if game and t_type:
            gametype = game + t_type
        elif game and (not t_type):
            gametype = game
        elif (not game) and t_type:
            gametype = t_type
        else:
            gametype = 'null'
        # logger.info(gametype)
        if gametype.encode('utf-8') == game_type:
            ret = gameid

    return ret