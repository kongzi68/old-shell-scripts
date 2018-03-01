# coding=utf-8
import commands
import logging
import re
import ConfigParser
from libs import id
from salt import client
from libs import db
from libs.db import getGameType


logger = logging.getLogger(__name__)
client = client.LocalClient()

cf = ConfigParser.ConfigParser()
cf.read('config/cmdb.conf')

# 关键词
gskeys = cf.get('keys', 'keys').replace(',', '|')
ex_gskeys = cf.get('keys', 'ex_keys').replace(',', '|')
no_ports = cf.get('keys', 'no_ports').split(',')

def checkUpdate(info):
    """
    :param info:
    :return:
    """
    t_sql = ''
    query = '''SELECT program_id, server_id, program, program_path, address, pid, port, status FROM t_program WHERE
               program_id='{0}';'''.format(info['program_id'])
    q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query, dict_ret=True)
    if not q_ret: return False

    for item in info.keys():
        t_item_txt = info.get(item, 'null')
        if item == 'program_path':  # TODO(colin):唉，很low的写法
            t_item_txt = t_item_txt.replace("\\\\", "\\")

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
        sql_update = '''UPDATE t_program SET {0} WHERE program_id='{1}';'''.format(t_sql, info.get('program_id'))
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
    sql_insert = '''INSERT INTO t_program (program_id, server_id, program, program_path, address, port, pid)
                    VALUES ('{program_id}', '{server_id}','{program}', "{program_path}", '{address}', {port},
                    {pid});'''.format(**info)
    sql_select = '''SELECT program_id FROM t_program WHERE program_id='{0}';'''.format(info['program_id'])
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

def getProcs(minion_id):
    """
    获取系统当前运行的进程信息
    :param minion_id:
    :return: {pid:[proc, proc_path],...}
    """
    ret = {}
    try:
        t_procs = client.cmd(minion_id, 'status.procs')[minion_id]
    except Exception, error:
        logger.error(error)
        return ret
    for key in t_procs.keys():
        t_string = t_procs[key]['cmd']
        try:
            # 触发异常，表示不符合要求，这里是匹配
            t_re = re.search(r'{0}'.format(gskeys), t_string, re.M|re.I).group()
        except AttributeError:
            t_re = False
        try:
            # 触发异常，表示符合要求，这里是排除
            t_re_ex = re.search(r'{0}'.format(ex_gskeys), t_string, re.M|re.I).span()
        except AttributeError:
            t_re_ex = True

        if t_re and t_re_ex:
            ret[key] = []
            ret[key].append(t_re)
            ret[key].append(t_string)

    return ret

def updateStatus(programs):
    """
    :param programs: {u'2947ebea2f37c5c9': ['42a657441cb2180a', '66aa16cc6c2f6f7b', '00232ed87049c2e3']}
    :return:
    """
    server_id = programs.keys()[0]
    program_ids = programs.values()[0]
    conn = db.getMysqlConn(db.host, db.port, db.user, db.passwd, db.dbname)
    cur = conn.cursor()
    sql_select = "SELECT program_id FROM t_program WHERE server_id='{0}';".format(server_id)
    if cur.execute(sql_select):
        for program_id in cur.fetchall():
            program_id = program_id[0]
            if program_id not in program_ids:
                sql_update = "UPDATE t_program SET status=0 WHERE program_id='{0}';".format(program_id)
                logger.info(sql_update)
                cur.execute(sql_update)
                conn.commit()

    cur.close()
    conn.close()

def execMainCheck(opt='all', opt_name='all'):
    """
    :param opt:
    :param opt_name:
    :return:
    """
    query = ''
    game_id = getGameType()
    if opt_name == 'all':
        query = '''SELECT server_id, CONCAT(ip, ',', netip) AS address, saltid FROM
                   t_server WHERE game_id={0} AND status=1;'''.format(game_id)
    elif opt_name == 'group':
        query = '''SELECT server_id, CONCAT(ip, ',', netip) AS address, saltid FROM
                   t_server WHERE game_id={0} AND env='{1}' AND status=1;'''.format(game_id, opt)
    elif opt_name == 'only':
        query = '''SELECT server_id, CONCAT(ip, ',', netip) AS address, saltid FROM
                   t_server WHERE game_id={0} AND saltid='{1}' AND status=1;'''.format(game_id, opt)

    q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query)
    logger.info(query)

    for server_id, address, salt_id in q_ret:
        programs = {server_id:[]}
        try:
            t_procs = getProcs(salt_id)
            grains = client.cmd(salt_id, 'grains.items')[salt_id]
        except Exception:
            # TODO(colin):这里报异常时，说明master与minion通信失败
            continue

        try:
            if grains['os'] == 'CentOS':
                t_ports = client.cmd(salt_id, 'cmd.run', ['netstat -ntlp'])[salt_id]
                # t_ports = commands.getoutput("salt {0} cmd.run 'netstat -ntlp'".format(salt_id))
            elif grains['os'] == 'Windows':
                t_ports = client.cmd(salt_id, 'cmd.run', ['netstat -ano'])[salt_id]
                # t_ports = commands.getoutput("salt {0} cmd.run 'netstat -ano'".format(salt_id))
            else:
                t_ports = 'null'
        except Exception, error:
            logger.info(error)
            t_ports = 'null'

        info = {}
        for pid in t_procs.keys():
            try:
                ports = re.search(r':([0-9]+) (.*) {0}'.format(pid), t_ports, re.M|re.I).group(1)
            except AttributeError:
                ports = False
            proc = t_procs.get(pid, 'null')[0]
            proc_path = t_procs.get(pid, 'null')[1]

            if ports or (proc in no_ports):
                info['pid'] = int(pid)
                info['port'] = int(ports)
                info['program'] = proc
                program_path = r"\\".join(proc_path.split('\\')).replace('"', '').strip()
                info['program_path'] = program_path
                program_id = id.getID(server_id, proc, program_path)
                info['program_id'] = program_id
                info['server_id'] = server_id
                info['address'] = address
                info['status'] = 1
                programs[server_id].append(program_id)
                logger.info(str(info))
                saveInfo(info)

        # logger.info(str(programs))
        updateStatus(programs)


