# coding=utf-8
import logging
import os
from libs import db
from libs.db import getGameType
from libs.libemail import sendEmail

gameid = getGameType()
logger = logging.getLogger(__name__)

ping_failed= 'log/ping_failure_server_list.txt'
temp_check_record = '/tmp/temp_check_record.txt'
mail_file = 'log/mail_file.txt'


def setServerStatus():
    with open(temp_check_record, 'rb') as f:
        record = f.read().splitlines()
    conn = db.getMysqlConn(db.host, db.port, db.user, db.passwd, db.dbname)
    cur = conn.cursor()
    query = "SELECT server_id FROM t_server WHERE status=1 AND game_id={0}".format(gameid)
    cur.execute(query)
    for server_id in cur.fetchall():
        server_id = server_id[0]
        if server_id not in record:
            sql_status = '''UPDATE t_server SET status=0 WHERE server_id='{0}' AND
                            game_id={1};'''.format(server_id, gameid)
            cur.execute(sql_status)
            conn.commit()
            logger.info(sql_status)
    cur.close()
    conn.close()
    if os.path.isfile(temp_check_record):
        os.remove(temp_check_record)


def checkResult():
    ret = {'failed':[], 'mail':False}
    conn = db.getMysqlConn(db.host, db.port, db.user, db.passwd, db.dbname)
    cur = conn.cursor()
    with open(ping_failed, 'rb') as f:
        for saltid in f:
            saltid = saltid.strip()
            query = "SELECT server_id FROM t_server WHERE saltid='{0}' AND game_id={1};".format(saltid, gameid)
            if cur.execute(query):
                server_id = cur.fetchone()[0]
                ret['failed'].append(server_id)
                sql_select = "SELECT server_id, times FROM t_pingfailure WHERE server_id='{0}';".format(server_id)
                if cur.execute(sql_select):
                    num = cur.fetchone()[1] + 1
                    if num >= 12: # 当saltstack的ping检查失败指定次后报警，并复位统计次数
                        with open(mail_file, 'ab+') as t_file:
                            t_strings = "    saltstack`s minion ID: {0}, server_id: {1};\n".format(saltid, server_id)
                            t_file.write(t_strings)
                            t_file.flush()
                        ret['mail'] = True
                        num = 1
                        sql_status = '''UPDATE t_server SET status=0 WHERE server_id='{0}' AND
                                        game_id={1};'''.format(server_id, gameid)
                        cur.execute(sql_status)

                    sql_update = "UPDATE t_pingfailure SET times={0} WHERE server_id='{1}';".format(num, server_id)
                    cur.execute(sql_update)
                else:
                    sql_insert = "INSERT INTO t_pingfailure VALUES ('{0}',{1});".format(server_id, 1)
                    cur.execute(sql_insert)

                conn.commit()
    cur.close()
    conn.close()
    return ret


def cleanPingLive(failed_list):
    """
    :param failed_list: 本次ping失败的minion清单
    :return:
    """
    conn = db.getMysqlConn(db.host, db.port, db.user, db.passwd, db.dbname)
    cur = conn.cursor()
    query = '''SELECT b.server_id FROM ( t_server a JOIN t_pingfailure b) WHERE a.game_id={0}
               AND a.server_id=b.server_id;'''.format(gameid)
    if cur.execute(query):
        old_failed_list = [ item[0] for item in cur.fetchall() ]
    else:
        old_failed_list = []

    # logger.info(str(old_failed_list))
    # 遍历上次的ping失败清单，若未在本次failed_list里面就清理掉
    # 表示上次ping检查失败，结果本次检测又ping通了
    for server_id in old_failed_list:
        if server_id not in failed_list:
            sql_delete = "DELETE FROM t_pingfailure WHERE server_id='{0}';".format(server_id)
            logger.info(sql_delete)
            cur.execute(sql_delete)
            conn.commit()

    cur.close()
    conn.close()

    return True

def execMain():
    # 给邮件内容加前缀
    with open(mail_file, 'ab+') as f:
        f.write('游戏版本: {0}, saltstack ping check failure list:\n'.format(db.game_type))

    # 对ping失败的清单进行处理
    t_ret = checkResult()
    logger.info(str(t_ret))
    if cleanPingLive(t_ret['failed']) and t_ret['mail']:
        with open(mail_file, 'rb') as f:
            content = f.read()
        sendEmail(content)

    # 设置退掉云服务器的status = 0
    setServerStatus()

    if os.path.isfile(mail_file):
        os.remove(mail_file)
