# coding=utf-8
import re
import logging
from salt import client
from libs import db
from libs.db import getGameType


logger = logging.getLogger(__name__)
client = client.LocalClient()

def checkUpdate(info):
    """
    :param info:
    :return:
    """
    t_sql = ''
    query = '''SELECT db_id, server_id, address, port, bind_db_id, db_relation, version, db_type, db_names
               FROM t_dbserver WHERE db_id='{0}';'''.format(info['db_id'])
    q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query, dict_ret=True)
    if not q_ret: return False

    for item in info.keys():
        t_item_txt = info.get(item, 'null')
        if t_item_txt != q_ret[0].get(item, 'null'):
            if t_item_txt in ['null', '']:
                continue
            if isinstance(t_item_txt, int):
                t_txt = "{0}={1}".format(item, t_item_txt)
            else:
                t_txt = "{0}='{1}'".format(item, t_item_txt)
            t_sql = '{0}, {1}'.format(t_sql, t_txt)

    t_sql = t_sql[1:]
    if t_sql:
        sql_update = '''UPDATE t_dbserver SET {0} WHERE db_id='{1}';'''.format(t_sql, info.get('db_id'))
        # logger.info(sql_update)
        return sql_update
    else:
        return False

def saveInfo(info):
    """
    :param info:
    :return:
    """
    conn = db.getMysqlConn(db.host, db.port, db.user, db.passwd, db.dbname)
    cur = conn.cursor()
    sql_insert = '''INSERT INTO t_dbserver (db_id, server_id, address, port, bind_db_id, db_relation, version,
                    db_type, db_names) VALUES
                    ('{db_id}', '{server_id}', '{address}', {port}, '{bind_db_id}', '{db_relation}', '{version}',
                    '{db_type}', '{db_names}');'''.format(**info)
    sql_select = '''SELECT db_id FROM t_dbserver WHERE db_id='{0}';'''.format(info['db_id'])
    sql_update = checkUpdate(info)
    if not cur.execute(sql_select):
        cur.execute(sql_insert)
        logger.info(sql_insert)
    elif sql_update:
        cur.execute(sql_update)
        logger.info(sql_update)
    conn.commit()
    cur.close()
    conn.close()

def getMasterProgramID(ip, t_port, game_id, m_program_id):
    """
    :param ip:
    :param tport:
    :param game_id:
    :return:
    """
    query = '''SELECT a.program_id FROM (t_program a JOIN t_server b) WHERE FIND_IN_SET('{0}', a.address) AND
               a.program='mysql' AND a.server_id=b.server_id AND a.port={1}
               AND b.game_id={2};'''.format(ip, t_port, game_id)
    try:
        q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query)
        # logger.info('{0}:::{1}'.format(query, q_ret))
        program_id = q_ret[0][0]
    except Exception:
        program_id = 'null'

    conn = db.getMysqlConn(db.host, db.port, db.user, db.passwd, db.dbname)
    cur = conn.cursor()
    try:
        sql_select = '''SELECT db_relation FROM t_dbserver WHERE db_id='{0}';'''.format(program_id)
        cur.execute(sql_select)
        relation_status = cur.fetchone()
        if relation_status[0] != 'master':
            sql_update = '''UPDATE t_dbserver SET bind_db_id='{0}', db_relation='master' WHERE
                            db_id='{1}';'''.format(m_program_id, program_id)
            cur.execute(sql_update)
            conn.commit()
    except Exception as error:
        pass
        # logger.error(error)
    finally:
        cur.close()
        conn.close()

    return program_id

def getMysqlRelation(pid, salt_id, game_id, program_id):
    """
    :param pid:
    :param salt_id:
    :return:
    """
    ret = []
    t_cmd = []
    t_command = "ls -l /proc/{0}".format(pid)+"|grep -E 'exe|cwd' |awk '{print $NF}'"
    t_cmd.append(t_command)
    try:
        exec_ret = client.cmd(salt_id, 'cmd.run', t_cmd)[salt_id].split()
        # logger.info('{0};;;{1}'.format(t_cmd, exec_ret))
        src_filename = client.cmd(salt_id, 'file.find', [exec_ret[0], 'type=f', 'name=master.info'])[salt_id]
        if src_filename:
            logger.info(str(src_filename))
            strings = client.cmd(salt_id, 'file.seek_read', [src_filename[0], 4096, 0])[salt_id].split()
            t_ip = strings[3]
            t_port= strings[6]
            bind_db_id = getMasterProgramID(t_ip, t_port, game_id, program_id)
            db_relation = 'slave'
        else:
            bind_db_id = 'null'
            db_relation = 'null'

        tmp_dbs = client.cmd(salt_id, 'file.find', [exec_ret[0], 'type=d'])[salt_id]
        db_names = ''
        for item in tmp_dbs:
            if item == exec_ret[0]: continue
            db = item.replace("{0}/".format(exec_ret[0]), '')
            if db not in ['mysql', 'performance_schema', 'test']:
                db_names = "{0},{1}".format(db, db_names)
    except KeyError as error:
        logger.error(error)
        return ret

    try:
        strings = client.cmd(salt_id, 'cmd.run', ["{0} -V".format(exec_ret[1])])[salt_id]
        # logger.info('{0}'.format(strings))
        version = re.match(r'.*([0-9]+.[0-9]+.[0-9]+)-.*', strings).group(1)
    except Exception as error:
        version = 'null'
        logger.error(error)

    ret.append(db_relation)
    ret.append(version)
    ret.append(bind_db_id)
    ret.append(db_names)

    return  ret

def getSaltID(server_id):
    """
    :param server_id:
    :return:
    """
    query = "SELECT saltid FROM t_server WHERE server_id='{0}';".format(server_id)
    q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query)
    return q_ret[0][0]

def execMainCheck(opt='all', opt_name='all'):
    """
    :return:
    """
    query = ''
    game_id = getGameType()
    if opt_name == 'all':
        query = '''SELECT program_id, server_id, address, pid, port FROM t_program WHERE program='mysql' AND
                   server_id IN (SELECT server_id FROM t_server WHERE game_id={0} AND status=1);'''.format(game_id)
    elif opt_name == 'group':
        query = '''SELECT program_id, server_id, address, pid, port FROM t_program WHERE program='mysql' AND
                   server_id IN (SELECT server_id FROM t_server WHERE
                   game_id={0} AND env='{1}' AND status=1);'''.format(game_id, opt)
    elif opt_name == 'only':
        query = '''SELECT program_id, server_id, address, pid, port FROM t_program WHERE program='mysql' AND
                   server_id IN (SELECT server_id FROM t_server WHERE
                   game_id={0} AND saltid='{1}' AND status=1);'''.format(game_id, opt)

    q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query)
    logger.info(query)

    for program_id, server_id, address, pid, t_port in q_ret:
        info = {}
        relation = getMysqlRelation(pid, getSaltID(server_id), game_id, program_id)
        if relation:
            db_relation, version , bind_db_id, db_names = relation
            info['bind_db_id'] = bind_db_id
            info['db_relation'] = db_relation
            info['version'] = version
            info['db_names'] = db_names
        info['db_id'] = program_id
        info['server_id'] = server_id
        info['address'] = address
        info['port'] = t_port
        info['db_type'] = 'mysql'

        saveInfo(info)
        logger.info(str(info))

    return True

