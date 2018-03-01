# coding=utf-8
import time
import logging
from libs import db
from libs.src.qcapi import getDataFromQcloudApi


logger = logging.getLogger(__name__)

def checkCdbUpdate(cdbinfo):
    """
    检查info字典里面的内容是否需要被更新
    :param cdbinfo:
    :return:
    """
    t_sql = ''
    query = '''SELECT uInstanceId,cdbInstanceName,cdbInstanceVip,cdbInstanceVport,memory,volume,
               cdbInstanceType,status,engineVersion,price,maxQueryCount FROM t_cdb WHERE
               uInstanceId='{0}';'''.format(cdbinfo.get('uInstanceId'))
    q_ret = db.getMysqlData(db.host, db.port, db.user, db.passwd, db.dbname, query, dict_ret=True)
    if not q_ret: return False

    for item in cdbinfo.keys():
        t_item_txt = cdbinfo.get(item, 'null')
        if isinstance(t_item_txt, str):
            t_item_txt = t_item_txt.decode('utf-8')
        t_q_ret_txt = q_ret[0].get(item, 'null')
        if t_item_txt != t_q_ret_txt:
            if t_item_txt in ['null', '']:
                continue
            if isinstance(t_item_txt, int) or isinstance(t_item_txt, float):
                t_txt = "{0}={1}".format(item, t_item_txt)
            else:
                t_txt = u"{0}='{1}'".format(item, t_item_txt)
            t_sql = u'{0}, {1}'.format(t_sql, t_txt)

    t_sql = t_sql[1:]
    if t_sql:
        sql_update = u'''UPDATE t_cdb SET {0} WHERE uInstanceId='{1}';'''.format(t_sql, cdbinfo.get('uInstanceId'))
        # logger.info('{0}'.format(sql_update))
        return sql_update
    else:
        return False

def getCdbPrice(memory, volume):
    """
    腾讯云限制单一api每1分钟内只能访问100次
    :param uninstanceid:
    :return: 返回的price，单位为元
    """
    time.sleep(0.7)
    module = 'cdb'
    action = 'InquiryCdbPrice'
    params = {'cdbType':'CUSTOM',
              'period':1,
              'goodsNum':1,
              'memory':memory,
              'volume':volume
              }
    api_data = getDataFromQcloudApi(module, action, params)
    if not api_data:
        return 0.00
    if api_data.get('codeDesc') == 'Success':
        return api_data.get('price', 0) / 100.00
    else:
        return 0.00

def getcdbInstanceSet(api_data):
    ret = []
    t_keys = ['uInstanceId',
              'cdbInstanceName',
              'cdbInstanceVip',
              'cdbInstanceVport',
              'memory',
              'volume',
              'cdbInstanceType',
              'status',
              'engineVersion',
              'price',
              'maxQueryCount'
              ]
    for items in api_data.get('cdbInstanceSet'):
        t_ret = {}
        for key in t_keys:
            if key == 'cdbInstanceName':
                t_ret[key] = items.get(key, 'null').encode('utf-8')
            elif key in ['memory', 'volume', 'cdbInstanceType', 'status', 'price']:
                t_ret[key] = items.get(key, 0)
            else:
                t_ret[key] = items.get(key, 'null')

        ret.append(t_ret)

    return ret

def saveCdbData():
    """
    params = { 'offset':(i * 100), 'limit':100 }
        Offset=0&Limit=20 返回第0到20项，
        Offset=20&Limit=20 返回第20到40项，
        Offset=40&Limit=20 返回第40到60项；以此类推。
    :return:
    """
    module = 'cdb'
    action = 'DescribeCdbInstances'
    params = { 'offset':0, 'limit':100 }
    api_data = getDataFromQcloudApi(module, action, params)
    if not api_data: return
    if api_data.get('codeDesc') == 'Success':
        nums = api_data.get('totalCount') // 100
        if nums > 0:
            api_ret = getcdbInstanceSet(api_data)
            for i in range(1, nums + 1):
                params = { 'offset':(i * 100), 'limit':100 }
                api_data = getDataFromQcloudApi(module, action, params)
                if not api_data: continue
                api_ret = api_ret + getcdbInstanceSet(api_data)
        else:
            api_ret = getcdbInstanceSet(api_data)
        conn = db.getMysqlConn(db.host, db.port, db.user, db.passwd, db.dbname)
        cur = conn.cursor()
        cur.execute("SELECT uInstanceId FROM t_cdb;")
        uInstanceIds = {uInstanceId[0] for uInstanceId in cur.fetchall()}
        for cdbinfo in api_ret:
            # logger.info(str(cdbinfo))
            uInstanceId = cdbinfo.get('uInstanceId', 'null')
            memory = cdbinfo.get('memory', 0)
            volume = cdbinfo.get('volume', 0)
            cdbinfo['price'] = getCdbPrice(memory, volume)
            if uInstanceId in uInstanceIds:
                sql_update = checkCdbUpdate(cdbinfo)
                if sql_update:
                    logger.info(sql_update)
                    cur.execute(sql_update)
            else:
                sql_insert = u"""INSERT INTO t_cdb (uInstanceId,cdbInstanceName,cdbInstanceVip,cdbInstanceVport,
                                memory,volume,cdbInstanceType,status,engineVersion,price,maxQueryCount)
                                VALUES ('{uInstanceId}', '{cdbInstanceName}', '{cdbInstanceVip}', '{cdbInstanceVport}',
                                {memory}, {volume}, {cdbInstanceType}, {status}, '{engineVersion}', {price},
                                '{maxQueryCount}');""".format(**cdbinfo)
                logger.info(sql_insert)
                cur.execute(sql_insert)
            conn.commit()

        cur.close()
        conn.close()
