#!/usr/bin/env python
#coding=utf-8
from salt import config, client
import sys, os, re, hashlib
import pymysql
import sqlite3
try:
    import xml.etree.cElementTree as ET
except ImportError:
    import xml.etree.ElementTree as ET
reload(sys)
sys.setdefaultencoding('utf-8')

#############################
# 设置需查找的文件夹关键词
# 比如国服IOS的路径为：D:\3JianHaoServer02\Data\Config\ServerConfig.xml
# 则关键词为：3JianHaoServer
dir_key = 'GS'
#############################
# Login.t_gameserver_list的连接信息
host = '10.116.4.223'
port = 3306
user = 'user1'
passwd = '123456'
# 指定sqlite3中的存储表名
table_name = 'th_gslist'

server_list_all = {}
file_name = 'ServerConfig.xml'
local = client.LocalClient()

def execMysqlCommand(dbname,query):
    conn = pymysql.connect(
        host=host,
        port=port,
        user=user,
        passwd=passwd,
        db=dbname,
        charset="utf8")
    cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()
    cur.close()
    conn.close()
    return result

def getMd5(*args):
    '''
    接收任意个字符串参数，生成16位md5，做ID值用
    '''
    string = ''
    for arg in args:
        string = '{0}{1}'.format(string, arg)
    string = str(string).encode('utf-8')
    m = hashlib.md5()
    m.update(string)
    return m.hexdigest()[8:-8]

def getServerConfig(game_server):
    '''
    查找指定服务器中的所有ServerConfig.xml
    '''
    disks = local.cmd(game_server, 'ps.disk_partitions').values()[0]
    for disk_info in disks:
        if disk_info['fstype'] == 'NTFS':
            disk_part = disk_info['mountpoint']
            salt_run_result = local.cmd(game_server, 'file.find', [disk_part, 'type=f', 'name=ServerConfig.xml'])
            file_lists = salt_run_result.values()[0]
            for tfile in file_lists:
                # 修复xml文件中属性没有加引号的配置
                # cccc = local.cmd(game_server, 'file.replace', [tfile, "pattern='ServerType=1'", "repl='ServerType=\"1\"'"])
                # print cccc
                tfile_key = tfile.split('\\')[1]
                # print tfile_key
                if dir_key in tfile_key:
                    file_txt_tmp = local.cmd(game_server, 'file.seek_read', [tfile, 4096, 0])
                    try:
                        # ServerConfig.xml文件中的编码替换
                        file_txt_tmp = file_txt_tmp.values()[0].encode('utf-8')
                        file_txt = re.sub("gb2312", "utf-8", file_txt_tmp)
                    except UnicodeDecodeError, error_info:
                        print error_info
                    finally:
                        f = open(file_name,"w")
                        f.write(str(file_txt) + "\n")
                        f.flush()
                        f.close()
                    print game_server, tfile
                    execParserXML(file_name, tfile, game_server)
                    os.system("rm {0} -f".format(file_name))

def execParserXML(file_name,sc_dir,game_server):
    '''
    解析ServerConfig.xml文件
    '''
    gs_info = {}
    gs_info['sc_dir'] = sc_dir
    tree = ET.ElementTree(file=file_name)
    for elem in tree.iter():
        if elem.tag == 'GameServer':
            tgs = elem.attrib
            for tkey in ('ID','Name','IP','IP2','Port'):
                if tkey == 'name':
                    gs_info["{0}{1}".format(elem.tag,tkey)] = tgs[tkey].encode("utf-8")
                else:
                    gs_info["{0}{1}".format(elem.tag,tkey)] = tgs[tkey]
                # 获取内网IP
                if tkey == 'IP' and tgs[tkey] == '0.0.0.0':
                    gs_info["{0}{1}".format(elem.tag,tkey)] = getGameServerIP(game_server)
        elif elem.tag in ('GameDBServer','ChargeDBServer','SoloGameDBServer'):
            tgs = elem.attrib
            for tkey in ('IP','DBName','Port'):
                gs_info["{0}{1}".format(elem.tag,tkey)] = tgs[tkey]
        elif elem.tag in ('OSSServer','LoginServer','CharMonitorServer'):
            tgs = elem.attrib
            gs_info["{0}{1}".format(elem.tag,'IP')] = tgs['IP']
    ip_port = "{0}:{1}".format(gs_info['GameServerIP2'], gs_info['GameServerPort'])
    gs_info['ip_port'] = ip_port
    key_value = getMd5(gs_info['GameServerIP2'], gs_info['sc_dir']) # 用getMd5函数计算ID值
    gs_info['ID'] = key_value
    server_list_all[key_value] = gs_info

def execParserResult():
    '''
    拉取login库中的正在运行服务器清单；
    与从所有游戏服务器拉取的配置文件清单进行比较；
    找出已部署的，但未使用的游戏服
    '''
    t_gameserver_list = {}
    query = "SELECT DISTINCT sip,port,sdbip,sdbport,sdbname,real_sid,real_sname FROM Login.t_gameserver_list;"
    game_server_real_list = execMysqlCommand('Login', query)
    for gs in game_server_real_list:
        t_gameserver_list["{0}:{1}".format(gs[0], gs[1])] = gs
    for t_gs in server_list_all.keys(): 
        tgs = server_list_all[t_gs]['ip_port']
        if tgs in t_gameserver_list.keys():
            server_list_all[t_gs]['sdbip'] = t_gameserver_list.get(tgs)[2].encode("utf-8")
            server_list_all[t_gs]['sdbport'] = str(t_gameserver_list.get(tgs)[3])
            server_list_all[t_gs]['sdbname'] = t_gameserver_list.get(tgs)[4].encode("utf-8")
            server_list_all[t_gs]['real_sid'] = str(t_gameserver_list.get(tgs)[5])
            server_list_all[t_gs]['real_sname'] = t_gameserver_list.get(tgs)[6].encode("utf-8")
            server_list_all[t_gs]['gs_status'] = 'used'
        else:
            server_list_all[t_gs]['gs_status'] = 'no_used'
    # print server_list_all

def execInsertData():
    '''
    把字典server_list_all中的数据，更新到sqlite3数据库
    '''
    execParserResult() # 执行函数，分析汇总后的结果，生成server_list_all字典
    conn = sqlite3.connect('gslist.db')
    cursor = conn.execute("SELECT ID FROM {0};".format(table_name))
    id_list = [ row[0] for row in cursor ]
    for ID in server_list_all.keys():
        gs_info_key = server_list_all.get(ID).keys()
        mod_txt = ''        
        if ID in id_list:
            for key_column in gs_info_key:
                if key_column != 'ID':
                    mod_txt_one = "{0}='{1}'".format(key_column,
                                server_list_all.get(ID)[key_column])
                    mod_txt = "{0},{1}".format(mod_txt, mod_txt_one)
            query_update = "UPDATE {0} SET {1} WHERE ID='{2}';".format(table_name,
                            mod_txt[1:], ID)     # 去第一个逗号
            print query_update
            conn.execute(query_update)
        else:
            for key_column in gs_info_key:
                mod_txt_one = "'{0}'".format(server_list_all.get(ID)[key_column])
                mod_txt = "{0},{1}".format(mod_txt, mod_txt_one)
            query_insert = "INSERT INTO {0} {1} VALUES ({2});".format(table_name,
                            str(tuple(gs_info_key)), mod_txt[1:])
            print query_insert            
            conn.execute(query_insert)
        conn.commit()
    conn.close()

def getGameServerIP(game_server):
    '''
    获取服务器的内网IP与外网IP
    返回结果为字符串：192.168.1.2,192.168.1.3
    '''
    ip_addrs_dic = local.cmd(game_server, 'network.ip_addrs')
    ip_addrs_list = ip_addrs_dic.values()[0]
    for ip_addr in ip_addrs_list:
        result = "{0},{1}".format(result, ip_addr)
    return result[1:]

def execPingCheck():
    '''
    检查salt-master配置文件/etc/salt/master
    GMServer分组中的游戏服务器是否在线
    '''
    server_list = list(config.master_config('/etc/salt/master')['nodegroups']['GMServer'].split('@')[1].split(','))
    ping_result = local.cmd('GMServer', 'test.ping', expr_form='nodegroup') 
    file = open('ping_filed_server_list.txt', "w+")
    for game_server in server_list:
        if game_server in ping_result.keys():
            getServerConfig(game_server)
        else:
            print "this ping flied: {0}".format(game_server)
            file.write(game_server + "\n")
            file.flush
    file.close

def main():
    # 执行ping检查
    execPingCheck()
    # 把分析结果插入gslist.db
    execInsertData()
    print "------------------------------"
    print "ping filed in file: ./ping_filed_server_list.txt"
    print "gameserver info in file: ./gslist.db"

if __name__ == '__main__':
    main()
    # import cProfile
    # import pstats

    # cProfile.run("main()", filename="result.out")
    # p = pstats.Stats("result.out")
    # p.strip_dirs().sort_stats("cumulative", "name").print_stats(0.1)
    