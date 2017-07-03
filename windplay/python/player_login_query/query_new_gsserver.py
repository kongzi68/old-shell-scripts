#!/usr/bin/env python
#coding=utf-8
# 新服数据分析
#+ 1、游戏服帐号与留存统计
#+ 2、查玩家流失清单
#+ 3、查充值汇总与周卡月卡汇总

# Import python libs
import copy
import datetime
import pymysql, time
import xlsxwriter

# Reload default encoding
import sys
reload(sys)
sys.setdefaultencoding("utf-8")

def query_mysql_result(host, port, user, passwd, dbname, query, 
                       dict_ret=False, isclose=True):
    '''
    查询数据库
    默认返回查询结果为嵌套元组；当dict_ret=True，返回结果为列表嵌套字典
    '''
    conn = pymysql.connect(host=host, port=port, user=user, passwd=passwd,
                           db=dbname, charset="utf8")
    
    if dict_ret:
        cur = conn.cursor(pymysql.cursors.DictCursor)
    else:
        cur = conn.cursor()
    cur.execute(query)
    result = cur.fetchall()
    # 默认关闭游标
    if isclose:
        cur.close()
        conn.close()

    return result


class UserTotalCount(object):
    '''
    用于统计帐号与玩家留存
    '''
    def __init__(self, server_lists, server_list):
        super(UserTotalCount, self).__init__()
        self.server_lists = server_lists
        self.server_list = server_list

    def return_result(self):
        '''
        汇总数据，返回结果为列表嵌套列表
        '''
        ret = []
        for sdbip,sdbport,sdbname,real_sid,real_sname in self.server_lists:
            if real_sid in self.server_list:
                t_ret = [real_sname, self.open_gs_date(sdbip, sdbport, sdbname)]
                add_user_count_dict = self.add_user_count(sdbip, sdbport, sdbname)
                user_life_count_dict = self.user_lifes(sdbip, sdbport, sdbname)
                for item in add_user_count_dict.keys():
                    t_ret.append(add_user_count_dict[item])
                for item in user_life_count_dict.keys():
                    t_ret.append(user_life_count_dict[item])
                ret.append(t_ret)

        # 把结果写到excel表格
        worksheet = workbook.add_worksheet('账号汇总与留存')
        col_data = [{'header': '游戏服'}, {'header': '开服时间'}, 
                    {'header': '1天'}, {'header': '2天'}, {'header': '3天'}, 
                    {'header': '4天'}, {'header': '5天'}, {'header': '6天'}, 
                    {'header': '7天'}, {'header': '次留'}, {'header': '3留'}, 
                    {'header': '7留'}, ]  # 这里必须要加一个逗号？
        worksheet.set_column(0, len(col_data) - 1, 15)
        tab_addrs = 'A1:{0}{1}'.format(chr(64 + len(col_data)), len(ret) + 1)
        options = {'data': ret,
                   'style': 'Table Style Light 11',
                   'columns': col_data}
        worksheet.add_table(tab_addrs, options)

        return ret

    @staticmethod
    def open_gs_date(host, port, dbname):
        '''
        查询开服时间
        '''
        query = ''' SELECT DATE_FORMAT(c_create_time, '%Y-%m-%d') AS ctime, 
                    COUNT( DATE_FORMAT(c_create_time, '%Y-%m-%d')) AS num 
                    FROM t_char_basic GROUP BY ctime HAVING num > 10 
                    ORDER BY ctime LIMIT 1; '''
        ret_query = query_mysql_result(host, port, 'root', '123456', 
                                        dbname, query, dict_ret=True)
        return ret_query[0]['ctime']

    def add_user_count(self, host, port, dbname):
        '''
        统计新增帐号
        按天统计,1~7天内的
        返回结果类似：{0: 491, 1: 532, 2: 246, 3: 360, 4: 355, 5: 332, 6: 317}
        '''
        reg_dict = {}
        strtime = self.open_gs_date(host, port, dbname)
        t_strtime = datetime.datetime.strptime(strtime, '%Y-%m-%d')
        endtime = t_strtime + datetime.timedelta(days = 6)
        endtime = endtime.strftime('%Y-%m-%d')
        query = ''' SELECT c_uid, DATE_FORMAT(inserttime, '%Y-%m-%d') AS ctime 
                    FROM t_account WHERE DATE_FORMAT(inserttime, '%Y-%m-%d') 
                    BETWEEN '{0}' AND '{1}';'''.format(strtime, endtime)
        reg_list = query_mysql_result('10.221.124.144',3306,'root','123456',
                                      'Login',query)
        for c_uid,ctime in reg_list:
            if ctime not in reg_dict.keys():
                reg_dict[ctime] = []
            else:
                reg_dict[ctime].append(c_uid)
        t_reg_dict = copy.deepcopy(reg_dict)
        query = "SELECT c_uid FROM t_char_basic"
        t_char_basic = query_mysql_result(host, port, 'root', '123456', 
                                          dbname, query)
        uid_lists = [i[0] for i in t_char_basic]
        for ctime, uid_day_list in t_reg_dict.items():
            for item in uid_day_list:
                if item not in uid_lists:
                    reg_dict[ctime].remove(item)
        ret = {}
        for i,item in enumerate(reg_dict.values()):
            ret[i] = len(item)
        return ret

    def user_lifes(self, host, port, dbname):
        '''
        玩家留存查询
        '''
        ret = {}
        lc_list = [1, 3, 7] # 查询留存为1、3、7
        daytime = time.strptime(self.open_gs_date(host, port, dbname), '%Y-%m-%d')
        
        # 查询游戏服所有的玩家角色清单
        query = "SELECT c_uid FROM t_char_basic"
        t_char_basic = query_mysql_result(host, port, 'root', '123456', 
                                          dbname, query)
        uid_lists = [i[0] for i in t_char_basic]

        # 从登录库中查询已登录帐号清单
        for x in lc_list:
            query = "SELECT DISTINCT uid, cid FROM Login{0}".format(x + daytime.tm_yday)
            login_record = query_mysql_result('10.221.168.131', 3306, 'root', 
                                              '123456', 'OSS', query)
            login_lists = [i[0] for i in login_record]
            num = 0
            for item in uid_lists:
                if item in login_lists: num += 1
            ret[x] = num

        return ret


class LosePlayer(object):
    """
    玩家流失数据统计
    各服务器流失的玩家等级及流失时间信息
    账号    角色名    玩家等级    流失时间
    """
    def __init__(self, server_lists, server_list, endtime):
        super(LosePlayer, self).__init__()
        self.server_lists = server_lists
        self.server_list = server_list
        self.endtime = endtime
    
    def return_result(self):
        '''
        返回结果字典，字典的key为real_sid,values为该服的玩家流失明细数据
        '''
        ret = {}
        col_data = [{'header': 'uid'}, {'header': 'account'}, 
                    {'header': 'cid'}, {'header': 'charname'}, 
                    {'header': 'level'}, {'header': '流失时间'},]

        for sdbip,sdbport,sdbname,real_sid,real_sname in self.server_lists:
            if real_sid in self.server_list:
                t_ret = self.lose_player_count(sdbip, sdbport, sdbname)
                ret[real_sid] = t_ret

                # 把结果写入excle表格,sheetname只接收字符串
                sname = ''.join(real_sname.split(' ')) # 去除空格
                worksheet = workbook.add_worksheet(sname)
                worksheet.set_column(0, len(col_data) - 1, 15)
                tab_addrs = 'A1:{0}{1}'.format(chr(64 + len(col_data)), len(t_ret) + 1)
                options = {'data': t_ret,
                           'style': 'Table Style Light 11',
                           'columns': col_data}
                worksheet.add_table(tab_addrs, options)

        return ret

    def lose_player_count(self, host, port, dbname):
        '''
        遍历该游戏服里面的所有角色
        返回结果为列表嵌套列表
        '''
        ret = []
        query = '''SELECT c_cid,c_uid,c_charname,c_level,
                   DATE_FORMAT(c_create_time, '%Y-%m-%d') AS ctime,
                   c_last_leave_time FROM t_char_basic;'''
        t_char_basic = query_mysql_result(host, port, 'root', '123456', 
                                          dbname, query)
        for cid, uid, charname, level, ctime, ltime in t_char_basic:
            ltime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(ltime))
            login_status = self.get_user_login_info(ctime, uid, cid)
            if login_status[0]:
                account = self.get_user_account(uid)
                t_list = [uid, account, cid, charname, level, str(ltime)]
                ret.append(t_list)
                print login_status[1], t_list
            else:
                print login_status[1]

        return ret

    def get_user_account(self, uid):
        '''
        根据UID查询账号名，返回结果为玩家的账号
        '''
        query = 'SELECT c_username FROM t_account WHERE c_uid = {0};'.format(uid)
        ret_query = query_mysql_result('10.221.124.144',3306,'root','123456',
                                       'Login',query)
        if ret_query:
            return ret_query[0][0]
        else:
            return None

    def get_user_login_info(self, ctime, uid, cid):
        '''
        根据玩家的uid，cid，查询玩家的登录日志记录，判断玩家是否流失
        返回结果为True：玩家流失；False：玩家存活
        计算玩家流失，应该以玩家的角色创建时间为始，以指定时间为止
        '''
        str_day = time.strptime(ctime, '%Y-%m-%d')
        end_day = time.strptime(self.endtime, '%Y-%m-%d')

        i = 0
        str_time = time.time()
        for day in range(str_day.tm_yday, end_day.tm_yday):
            query = '''SELECT uid, cid FROM Login{0} WHERE uid = {1} AND 
                       cid = {2};'''.format(day, uid, cid)
            ret_query = query_mysql_result('10.221.168.131', 3306, 'root', 
                                           '123456', 'OSS', query, 
                                           isclose=False)
            # 判断逻辑：
            # 只要查询到数据，就重置，i = 0
            # 若未查询到数据，i 就自增，当 i >= 7
            #+ 就说明连续7天未登陆，就满足了流失条件
            # 若整个循环完成，函数都未返回 True，那说明玩家存活,循环结束返回False
            if ret_query:
                i = 0
            else:
                i += 1
                if i >= 7: 
                    end_time = time.time()
                    return [True, end_time - str_time]

        end_time = time.time()
        return [False, end_time - str_time]


class ChargeOrderCount(object):
    '''
    充值订单汇总统计
    (10100217, 10100218, 10100219, 10100220, 10100221)
    '''
    def __init__(self, strtime, endtime, server_list):
        super(ChargeOrderCount, self).__init__()
        self.server_list = server_list
        self.strtime = strtime
        self.endtime = endtime

    def return_result(self):
        '''
        返回结果为列表嵌套列表，并把结果写入excel表格
        '''
        ret = []
        col_data = [{'header':'游戏服'},{'header':'总金额'},
                    {'header':'6元_ALL'},{'header':'30元_ALL'},
                    {'header':'98元'},{'header':'128元'},
                    {'header':'328元'},{'header':'648元'},
                    {'header':'MN648元'},{'header':'周卡'},
                    {'header':'月卡'},]

        for sid in self.server_list:
            ret_count = self.get_charge_order_count(sid)
            if ret_count:
                t_ret = ret_count[sid]
                ret_card = self.get_charge_by_card(sid)
                if ret_card:
                    t_ret.append(ret_card[65])
                    t_ret.append(ret_card[350])
            ret.append(t_ret)

        # 把结果写到excel表格
        worksheet = workbook.add_worksheet('充值汇总统计')
        worksheet.set_column(0, len(col_data) - 1, 15)
        tab_addrs = 'A1:{0}{1}'.format(chr(64 + len(col_data)), len(ret) + 1)
        options = {'data': ret,
                   'style': 'Table Style Light 11',
                   'columns': col_data}
        worksheet.add_table(tab_addrs, options)

        return ret

    def get_gs_sname(self, sid):
        '''
        获取游戏服的名称
        返回结果为字符串，游戏服的名称
        '''
        ret = None
        query = '''SELECT DISTINCT real_sname FROM t_gameserver_list 
                   WHERE sid = {0}; '''.format(sid)
        ret_query = query_mysql_result('10.221.124.144', 3306, 'root', 
                                       '123456', 'Login', query)
        
        if ret_query: ret = ''.join(ret_query[0][0].split(' '))

        return ret

    def get_charge_order_count(self, sid):
        '''
        获取充值订单汇总
        返回结果为字典嵌套列表：{sid:[]}
        '''
        ret = {}
        query = '''SELECT sid, sum(totalmoney) as money,
                   sum( CASE WHEN product_id='{0}20001' THEN 1 ELSE 0 END ) AS order_6, 
                   sum( CASE WHEN product_id='{0}20002' THEN 1 ELSE 0 END ) AS order_30, 
                   sum( CASE WHEN product_id='{0}20003' THEN 1 ELSE 0 END ) AS order_98, 
                   sum( CASE WHEN product_id='{0}20004' THEN 1 ELSE 0 END ) AS order_128, 
                   sum( CASE WHEN product_id='{0}20005' THEN 1 ELSE 0 END ) AS order_328,
                   sum( CASE WHEN product_id='{0}20006' THEN 1 ELSE 0 END ) AS order_648,
                   sum( CASE WHEN product_id='{0}20022' THEN 1 ELSE 0 END ) AS order_MN_648 
                   FROM IOSFinish WHERE DATE_FORMAT(time, '%Y-%m-%d') BETWEEN '{1}' AND '{2}' 
                   AND sid = {3};'''.format('com.windplay.threeswordsmen2.product', 
                                            self.strtime, self.endtime, sid)
        ret_query = query_mysql_result('10.221.124.144', 3306, 'root', 
                                       '123456', 'Charge', query)
        if ret_query:
            sid, tmoney, o_6, o_30, o_98, o_128, o_328, o_648, o_mn648 = ret_query[0]
            sname = self.get_gs_sname(sid) # 获取游戏服名称
            ret = {sid:[sname, tmoney, o_6, o_30, o_98, o_128, o_328, o_648, o_mn648]}

        return ret

    def get_charge_by_card(self, sid):
        '''
        获取充值月卡周卡汇总
        返回结果为字典：{ubg:toltal_order}
        '''
        query = '''SELECT sum(order_num) AS toltal_order, ubg
                   FROM RechargeMember_daily 
                   WHERE starttime BETWEEN '{0}' AND '{1}' AND serverid = {2} 
                   GROUP BY ubg;'''.format(self.strtime, self.endtime, sid)
        ret_query = query_mysql_result('10.221.168.131', 3306, 'root', 
                                       '123456', 'Statistics', query)

        ret = {ubg : toltal_order for toltal_order, ubg in ret_query if ret_query}

        return ret

if __name__ == '__main__':
    # 拉取游戏服清单
    query = '''SELECT DISTINCT sdbip,sdbport,sdbname,real_sid,real_sname 
               FROM t_gameserver_list; '''
    server_lists = query_mysql_result('10.221.124.144', 3306, 'root', 
                                      '123456', 'Login', query)
    # 把结果写到excel表格
    filename = 'dataAnalysisStatistical.xlsx'
    workbook = xlsxwriter.Workbook(filename)
    tab_format = workbook.add_format({'bold': True})
    tab_format.set_align('center')
    tab_format.set_align('vcenter')
    
    # 需要查询的游戏服列表，值为real_sid
    server_list = [ 10100010,10100037,10100061,10100099,10100118,10100140,
                    10100159,10100173,10100198,10100211,10100221,10100229,
                    10100231,10100233,10100235,10100237,10100239,10100240,
                    10100241,10100242,10100243,10100244 ]

    # 游戏服帐号与留存统计
    testa = UserTotalCount(server_lists, server_list)
    data = testa.return_result()
    
    # 查玩家流失
    testb = LosePlayer(server_lists, server_list, '2017-05-11')
    ret = testb.return_result()
    
    # 查充值汇总与周卡月卡汇总
    sid_list = [ 10100010,10100037,10100061,10100099,10100118,10100140,
                    10100159,10100173,10100198,10100211,10100221,10100229,
                    10100231,10100233,10100235,10100237,10100239,10100240,
                    10100241,10100242,10100243,10100244 ]
    sid_list = server_list
    testc = ChargeOrderCount('2017-05-03', '2017-05-11', sid_list)
    ret = testc.return_result()

    workbook.close()
    print "result in file: ./{0} ".format(filename)

