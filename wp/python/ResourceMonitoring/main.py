#!/usr/bin/env python
# coding=utf-8
import datetime
import logging
import os
from libs import db
from libs import liblog
from libs.libemail import sendEmail
from libs.common import str_code
from modules import r_monitor

liblog.setup_logging()
logger = logging.getLogger(__name__)
temp_files = 'log/low_load_server.txt'


def get_game_type():
    ret = {}
    query = "SELECT game_id, game, `type` FROM t_gametype;"
    q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query)
    for gameid, game, t_type in q_ret:
        if game and t_type:
            gametype = game + t_type
        elif game and (not t_type):
            gametype = game
        elif (not game) and t_type:
            gametype = t_type
        else:
            gametype = 'null'

        ret[gameid] = gametype

    return ret

def cvm():
    query = """SELECT uninstanceid,cvmtype,game_id FROM t_server WHERE `status` = 1 AND uninstanceid <> ''
               AND cvmtype <> '' ORDER BY game_id,cvmtype;"""
    try:
        q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query)
        gameids = get_game_type()
        for uninstanceid, cvmtype, gameid in q_ret:
            logger.info(uninstanceid)
            cvm_monitor = r_monitor.CvmCollect(uninstanceid, cvmtype)
            t_ret = cvm_monitor.cvm_main()
            if t_ret:
                gametype = str_code(gameids.get(gameid))
                cvmtype = str_code(cvmtype)
                strings = '{0};{1};{2};{3}'.format(uninstanceid, gametype, cvmtype, t_ret)
                with open(temp_files, 'ab+') as f:
                    f.write('{0}\n'.format(strings))
                logger.info(strings.decode('utf-8'))
    except Exception as error:
        logger.error(error, exc_info=1)
        pass

def cdb():
    query = """SELECT uInstanceId,cdbInstanceName,cdbInstanceVip,memory,maxQueryCount FROM t_cdb
               WHERE `status` = 1 AND uInstanceId <> '';"""
    try:
        q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query)
        for uInstanceId, cdbInstanceName, cdbInstanceVip, memory, maxQueryCount in q_ret:
            logger.info(uInstanceId)
            cdb_monitor = r_monitor.CdbCollect(uInstanceId, memory, maxQueryCount)
            t_ret = cdb_monitor.cdb_main()
            if t_ret:
                strings = '{0};{1};{2};{3}'.format(uInstanceId,
                                                   str_code(cdbInstanceName),
                                                   str_code(cdbInstanceVip),
                                                   t_ret)
                with open(temp_files, 'ab+') as f:
                    f.write('{0}\n'.format(strings))
                logger.info(strings.decode('utf-8'))
    except Exception as error:
        logger.error(error, exc_info=1)
        pass


if __name__ == '__main__':
    if not os.path.exists('./log'):
        os.mkdir('./log')
    if os.path.isfile(temp_files):
        os.remove(temp_files) # 清理上次产生的文件
    logger.info('Running.')
    # 获取云服务器中的低负载机器
    cvm()
    # 获取云数据库mysql中的低负载机器
    cdb()
    # 发邮件
    if os.path.isfile(temp_files):
        with open(temp_files, 'rb') as f:
            mail_content = f.read()
        now_time = datetime.datetime.now()
        strings = '{0}，第{1}周，低负载云服务器与云数据库mysql清单:\n'.format(
            now_time.strftime("%Y-%m-%d"), now_time.strftime('%W'))
        content = strings + mail_content
        sendEmail('低负载云服务器与云数据库mysql', content, temp_files)
    logger.info('Done.')

