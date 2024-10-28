# coding=utf-8
import commands
import os
import logging
import psutil
import time
import ConfigParser
from t_cdb import saveCdbData
from salt import config, client
from t_pingfailure import execMain as setServerStatus
from libs import id
from libs import db
from libs.db import getGameType
from libs.src.qcapi import getDataFromQcloudApi


logger = logging.getLogger(__name__)
client = client.LocalClient()
t_config = config.master_config('/etc/salt/master')['nodegroups']
ping_failed= 'log/ping_failure_server_list.txt'
temp_check_record = '/tmp/temp_check_record.txt'

cf = ConfigParser.ConfigParser()
cf.read('config/cmdb.conf')
iscloudserver = cf.getboolean('config', 'iscloudserver')
isgetcdb = cf.getboolean('config', 'isgetcdb')
hour = cf.getint('config', 'hour')


def getApiInstanceSet(api_data):
    ret = []
    for item in api_data.get('instanceSet'):
        t_ret = []
        t_ret.append(item.get('unInstanceId', 'null'))
        t_ret.append(item.get('lanIp', 'null'))
        t_ret.append(item.get('wanIpSet', 'null')[0])
        t_ret.append(item.get('bandwidth', 'null'))
        ret.append(t_ret)

    return ret

def getApiServerPrice(uninstanceid):
    """
    腾讯云限制单一api每1分钟内只能访问100次
    :param uninstanceid:
    :return: 返回的price，单位为元
    """
    time.sleep(0.7)
    module = 'cvm'
    action = 'InquiryInstancePrice'
    params = {'instanceType':1, 'instanceId':uninstanceid, 'period':1}
    api_data = getDataFromQcloudApi(module, action, params)
    if not api_data:
        return 0.00
    if api_data.get('codeDesc') == 'Success':
        return api_data.get('price', 0) / 100.00
    else:
        return 0.00

def saveApiData():
    """
    params = { 'offset':(i * 100), 'limit':100 }
        Offset=0&Limit=20 返回第0到20项，
        Offset=20&Limit=20 返回第20到40项，
        Offset=40&Limit=20 返回第40到60项；以此类推。
    :return:
    """
    module = 'cvm'
    action = 'DescribeInstances'
    params = { 'offset':0, 'limit':100 }
    api_data = getDataFromQcloudApi(module, action, params)
    if not api_data: return
    if api_data.get('codeDesc') == 'Success':
        nums = api_data.get('totalCount') // 100
        if nums > 0:
            api_ret = getApiInstanceSet(api_data)
            for i in range(1, nums + 1):
                params = { 'offset':(i * 100), 'limit':100 }
                api_data = getDataFromQcloudApi(module, action, params)
                if not api_data: continue
                api_ret = api_ret + getApiInstanceSet(api_data)
        else:
            api_ret = getApiInstanceSet(api_data)

        gameid = getGameType()
        conn = db.getMysqlConn(db.host, db.port, db.user, db.passwd, db.dbname)
        cur = conn.cursor()
        for uninstanceid, ip, netip, bandwidth in api_ret:
            sql_select = """SELECT ip, netip, uninstanceid, price, bandwidth FROM t_server WHERE
                            game_id={0} AND ip='{1}';""".format(gameid, ip)
            if cur.execute(sql_select):
                t_sql = []
                price = getApiServerPrice(uninstanceid)
                _, o_netip, o_uninstanceid, o_price, o_bandwidth = cur.fetchone()
                if o_netip != netip:
                    t_sql.append("netip='{0}'".format(netip))
                if o_uninstanceid != uninstanceid:
                    t_sql.append("uninstanceid='{0}'".format(uninstanceid))
                if o_price != price:
                    t_sql.append("price={0}".format(price))
                if o_bandwidth != bandwidth:
                    t_sql.append("bandwidth={0}".format(bandwidth))

                if t_sql:
                    data = ''
                    for item in t_sql:
                        data = "{0}, {1}".format(data, item)
                    sql_update = """UPDATE t_server SET {0} WHERE game_id={1} AND
                                    ip='{2}';""".format(data[1:], gameid, ip)
                    logger.info(sql_update.decode('utf-8'))
                    cur.execute(sql_update)
                    conn.commit()

        cur.close()
        conn.close()

def checkUpdate(info):
    """
    检查info字典里面的内容是否需要被更新
    :param info: getInfo()函数采集的服务器基本信息，格式为字典
    :return:
    """
    t_sql = ''
    query = '''SELECT server_id, game_id, hostname, ip, netip, os, cpu, mem, disk, status, env, saltid FROM
               t_server WHERE server_id='{0}';'''.format(info['server_id'])
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
        sql_update = '''UPDATE t_server SET {0} WHERE server_id='{1}';'''.format(t_sql, info.get('server_id'))
        # logger.info('{0}'.format(sql_update))
        return sql_update
    else:
        return False

def saveInfo(info):
    """
    把采集的服务器信息写入数据库
    :param info: getInfo()函数采集的服务器基本信息，格式为字典
    :return:
    """
    conn = db.getMysqlConn(db.host, db.port, db.user, db.passwd, db.dbname)
    cur = conn.cursor()
    sql_insert = '''INSERT INTO t_server (server_id, game_id, hostname, ip, netip, os, cpu, mem, disk, env, saltid)
                    VALUES ('{server_id}', {game_id},'{hostname}', '{ip}', '{netip}', '{os}', '{cpu}', {mem}, {disk},
                    '{env}', '{saltid}');'''.format(**info)
    sql_select = '''SELECT server_id FROM t_server WHERE server_id='{0}';'''.format(info['server_id'])
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


def getGameEnv():
    ret = {}
    t_ret = {}
    for item in t_config.keys():
        # logger.info('{0}, {1}'.format(item, minion_id))
        servers = t_config[item].split('@')[1].split(',')
        for saltid in servers:
            t_ret.setdefault(saltid, []).append(item)
    for key, value in t_ret.items():
        envs = ""
        for env in value:
            envs += ',' + env
        ret[key] = envs[1:]
    return ret


env_dict = getGameEnv()
def getInfo(minion_id):
    """
    # 获取云服务器的一些基本信息
    :param minion_id: saltstack的minion端id
    :return: 字典
    """
    ret = {}
    try:
        info = client.cmd(minion_id, 'grains.items')[minion_id]
    except KeyError, error:
        logger.info(error)
        return ret
    disk_total = 0
    if info.get('os', 'null') in ['CentOS', 'Ubuntu']:
        ret['os'] = "{0} {1},{2} {3}".format(info['os'], info['osrelease'], info['kernel'], info['kernelrelease'])
        t_disk = commands.getoutput("df -P|awk '(NR != 1){print $2}'").split('\n')
        for item in t_disk:
            disk_total += int(item)
            # logger.info('{0}'.format(disk_total))
        ret['disk'] = disk_total/1000/1000     # 1024-blocks
    elif info.get('os', 'null') == 'Windows':
        ret['os'] = "{0} {1}".format(info['osfullname'], info['osversion'])
        try:
            tdisk = psutil.disk_partitions()
            for i in range(0, len(tdisk)):
                mountpoint = tdisk[i].mountpoint
                disk_total += psutil.disk_usage(mountpoint).total
        except Exception:
            pass
        ret['disk'] = disk_total/1000/1000/1000    # 字节
    elif info.get('os', 'null') == 'null':
        logger.error('Get grains is failed, saltid: {0}'.format(minion_id))
        return ret
    ret['game_id'] = getGameType()
    ret['env'] = env_dict.get(minion_id)
    ret['cpu'] = "{0}[{1}]".format(info['cpu_model'], info['num_cpus'])
    ret['mem'] = info['mem_total']
    ip = [ item for item in info['ipv4'] if item != 'iamIPaddress' ]
    ret['ip'] = ip[0]
    ret['saltid'] = info['id']
    ret['netip'] = info.get('netip', 'null').rstrip()
    ret['hostname'] = info['host']
    ret['server_id'] = id.getID(ip, info['id'])
    ret['status'] = 1
    logger.info('{0}'.format(ret))
    return  ret

def execCommand(salt_id, opt_name):
    """
    :param salt_id:
    :param opt_name:
    :return:
    """
    ping_result = client.cmd(salt_id, 'test.ping')
    try:
        # 若salt_id不通，check_result结果为空字典
        # 正常：{'centos_iamIPaddress': 'centos_iamIPaddress'}
        check_result = client.cmd(salt_id, 'grains.get', ['id'])
    except Exception as error:
        check_result = None
        logger.error(error)
    with open(ping_failed, 'ab+') as f:
        if ping_result and check_result:
            logger.info("{0}".format(salt_id))
            t_dict = getInfo(salt_id)
            if t_dict:
                saveInfo(t_dict)
                if opt_name == 'all':
                    serverid = t_dict.get('server_id', None)
                    with open(temp_check_record, 'ab+') as f_record:
                        f_record.write(serverid + "\n")
                        f_record.flush()
        else:
            logger.error("Ping flied: {0}".format(salt_id))
            f.write(salt_id + "\n")
            f.flush()

def execSaveApiData():
    """
    每周二、四、六执行从云服务器采集数据
    :return:
    """
    lock = id.Lock()
    # run_week = [1, 3, 5]
    now_time = time.strptime(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()), "%Y-%m-%d %H:%M:%S")
    if not iscloudserver:
        return False
    # if not now_time.tm_wday in run_week:
    #     lock.unlock()
    #     return False
    if now_time.tm_hour == 23:
        lock.unlock()        
    if hour == now_time.tm_hour or not lock.islock():
        logger.info('Get server`s price from qcloud.')
        saveApiData()
        if isgetcdb: # 云数据库是直接从腾讯云api获取，未按游戏分类获取，只要有一个能拉取即可
            logger.info('Get cdb`s info from qcloud.')
            saveCdbData()
        lock.lock()

def execMainCheck(opt='all', opt_name='all'):
    """
    :param opt:
    :param opt_name:
    :return:
    """
    if os.path.isfile(ping_failed):
        os.remove(ping_failed)

    if opt_name == 'all':
        for item in t_config.keys():
            servers = t_config[item].split('@')[1].split(',')
            for salt_id in servers:
                execCommand(salt_id, opt_name)

        execSaveApiData()
        setServerStatus()
        return True

    elif opt_name == 'group':
        if opt in t_config.keys():
            servers = t_config[opt].split('@')[1].split(',')
            for salt_id in servers:
                execCommand(salt_id, opt_name)

            execSaveApiData()
            return True
        else:
            logger.error('The saltstack`s master group_name is error, Please check.')
            return False

    elif opt_name == 'only':
        check_status = False
        for item in t_config.keys():
            servers = t_config[item].split('@')[1].split(',')
            if opt in servers:
                check_status = True

        if check_status:
            execCommand(opt, opt_name)
            execSaveApiData()
            return True
        else:
            logger.error('The saltstack`s minion id is error, Please check.')
            return False
