# coding=utf-8
from __future__ import division
import ast
import datetime
import logging
import ConfigParser
from libs.src.qcapi import getDataFromQcloudApi

logger = logging.getLogger(__name__)
now_time = datetime.datetime.now()
cf = ConfigParser.ConfigParser()
cf.read('config/config.conf')


class CvmCollect(object):
    """
    云服务器
    计算规则：
        每5分钟取一个数据点，去掉将全天288个数据点中最大的12个（削峰）后的最大值作为当天的使用率数据；
        每周取7天的最大值作为周利用率数据；
        只要有任意一个指标满足，就不认为是低负载机器
    """
    def __init__(self, unInstanceId, cvmtype):
        super(CvmCollect, self).__init__()
        self.module = 'monitor'
        self.action = 'GetMonitorData'
        self.unInstanceId = unInstanceId
        self.cvmtype = cvmtype.encode('utf-8')
        self.quota = ['cpu_usage', 'mem_usage']
        self.quota_traffic = ['lan_outtraffic', 'lan_intraffic', 'wan_outtraffic', 'wan_intraffic']
        self.cvmtype1 = self.configsplit(cf.get('cvm', 'cvmtype1'))
        self.cvmtype1_rule = ast.literal_eval(cf.get('cvm', 'cvmtype1_rule'))
        self.cvmtype2 = self.configsplit(cf.get('cvm', 'cvmtype2'))
        self.cvmtype2_rule = ast.literal_eval(cf.get('cvm', 'cvmtype2_rule'))

    @staticmethod
    def configsplit(configstring):
        ret = []
        if configstring.find(',') >=0:
            ret = configstring.split(',')
        else:
            ret = [configstring]
        return ret

    @staticmethod
    def get_time():
        ret = []
        for item in range(-7, 0):
            t_time = now_time + datetime.timedelta(days = item)
            ret.append(t_time.strftime("%Y-%m-%d"))
        return ret

    def get_cvm_apidata(self):
        '''
        不用相加的指标
        :return:
        '''
        ret = {}
        for day_time in self.get_time():
            ret[day_time] = {}
            for quota_item in self.quota:
                params = {'namespace':'qce/cvm',
                          'dimensions.0.name':'unInstanceId',
                          'dimensions.0.value':self.unInstanceId,
                          'metricName':quota_item,
                          'period':300,
                          'startTime':'{0} 00:00:00'.format(day_time),
                          'endTime':'{0} 23:59:59'.format(day_time)}

                api_ret = getDataFromQcloudApi(self.module, self.action, params)
                if api_ret.get('codeDesc') == 'Success':
                    t_list = api_ret.get('dataPoints')
                    t_list.sort(reverse=True)
                    ret[day_time][quota_item] = t_list[12]
                else:
                    ret[day_time][quota_item] = 0
                    logger.error('Get data: {0},{1} is unsuccessfully'.format(day_time, quota_item))

        return ret

    def get_cvm_traffic_apidata(self):
        '''
        需要相加的指标
        :return:
        '''
        ret = {}
        for day_time in self.get_time():
            ret[day_time] = {}
            t_ret = {}
            for quota_item in self.quota_traffic:
                params = {'namespace':'qce/cvm',
                          'dimensions.0.name':'unInstanceId',
                          'dimensions.0.value':self.unInstanceId,
                          'metricName':quota_item,
                          'period':300,
                          'startTime':'{0} 00:00:00'.format(day_time),
                          'endTime':'{0} 23:59:59'.format(day_time)}

                api_ret = getDataFromQcloudApi(self.module, self.action, params)
                if api_ret.get('codeDesc') == 'Success':
                    t_ret[quota_item] = api_ret.get('dataPoints')
                else:
                    t_ret[quota_item] = []
                    logger.error('Get data: {0},{1} is unsuccessfully'.format(day_time, quota_item))

            lan_out = t_ret.get(self.quota_traffic[0], [])
            lan_out = [i for i in lan_out if i != None]
            lan_in = t_ret.get(self.quota_traffic[1], [])
            lan_in = [i for i in lan_in if i != None]
            wan_out = t_ret.get(self.quota_traffic[2], [])
            wan_out = [i for i in wan_out if i != None]
            wan_in = t_ret.get(self.quota_traffic[3], [])
            wan_in = [i for i in wan_in if i != None]

            try:
                if lan_out and lan_in:
                    lan = [ round(x + y, 2) for x, y in zip(lan_out, lan_in) ]
                else:
                    lan = lan_out + lan_in
                lan.sort(reverse=True)
                ret[day_time]['lan'] = lan[0]
            except Exception:
                ret[day_time]['lan'] = 0
                pass

            try:
                if wan_out and wan_in:
                    wan = [ round(x + y, 2) for x, y in zip(wan_out, wan_in) ]
                else:
                    wan = wan_out + wan_in
                wan.sort(reverse=True)
                ret[day_time]['wan'] = wan[0]
            except Exception:
                ret[day_time]['wan'] = 0
                pass

        return ret

    def get_week_data(self):
        ret = {}
        ret1 = self.get_cvm_apidata()
        ret2 = self.get_cvm_traffic_apidata()

        for key in self.quota:
            t_ret = []
            for item in ret1.values():
                t_ret.append(item.get(key, 0))
            t_ret.sort(reverse=True)
            ret[key] = t_ret[0]

        for key in ['lan', 'wan']:
            t_ret = []
            for item in ret2.values():
                t_ret.append(item.get(key, 0))
            t_ret.sort(reverse=True)
            ret[key] = t_ret[0]

        return ret

    def cvm_main(self):
        ret = {}
        x = 0
        week_data = self.get_week_data()
        for key, value in week_data.items():
            if self.cvmtype in self.cvmtype1:
                if self.cvmtype1_rule.get(key) >= value:
                    x += 1
                    ret[key] = value
            elif self.cvmtype in self.cvmtype2:
                if self.cvmtype2_rule.get(key) >= value:
                    x += 1
                    ret[key] = value

        if self.cvmtype in self.cvmtype1:
            rules = len(self.cvmtype1_rule)
        elif self.cvmtype in self.cvmtype2:
            rules = len(self.cvmtype2_rule)
        else:
            rules = 0

        if x >= rules:
            return ret
        else:
            return False


class CdbCollect(object):
    """
    云数据库MySQL
    计算规则：
        每5分钟取一个数据点，去掉将全天288个数据点中最大的12个（削峰）后的最大值作为当天的使用率数据；
        每周取7天的最大值作为周利用率数据；
        只要有任意一个指标满足，就不认为是低负载机器
    """
    def __init__(self, uInstanceId, memory, maxQueryCount):
        super(CdbCollect, self).__init__()
        self.module = 'monitor'
        self.action = 'GetMonitorData'
        self.uInstanceId = uInstanceId
        self.memory = memory
        self.maxQueryCount = maxQueryCount
        self.quota = ['queries','real_capacity','capacity','memory_use']
        self.cdbtype1 = CvmCollect.configsplit(cf.get('cdb', 'cdbtype1'))
        self.cdbtype1_rule = ast.literal_eval(cf.get('cdb', 'cdbtype1_rule'))

    def get_cdb_apidata(self):
        '''
        不用相加的指标
        :return:
        '''
        ret = {}
        for day_time in CvmCollect.get_time():
            ret[day_time] = {}
            for quota_item in self.quota:
                params = {'namespace':'qce/cdb',
                          'dimensions.0.name':'uInstanceId',
                          'dimensions.0.value':self.uInstanceId,
                          'metricName':quota_item,
                          'period':300,
                          'startTime':'{0} 00:00:00'.format(day_time),
                          'endTime':'{0} 23:59:59'.format(day_time)}

                api_ret = getDataFromQcloudApi(self.module, self.action, params)
                if api_ret.get('codeDesc') == 'Success':
                    t_list = api_ret.get('dataPoints')
                    t_list.sort(reverse=True)
                    ret[day_time][quota_item] = t_list[12]
                else:
                    ret[day_time][quota_item] = 0
                    logger.error('Get data: {0},{1} is unsuccessfully'.format(day_time, quota_item))

        return ret

    def get_week_data(self):
        ret = {}
        ret1 = self.get_cdb_apidata()

        for key in self.quota:
            t_ret = []
            for item in ret1.values():
                t_ret.append(item.get(key, 0))
            t_ret.sort(reverse=True)
            ret[key] = t_ret[0]

        return ret

    def cdb_main(self):
        ret = {}
        x = 1
        week_data = self.get_week_data()

        if week_data.get('queries') <= self.cdbtype1_rule.get('queries'):
            ret['queries'] = week_data.get('queries')
            return ret
        else:
            ret['queries'] = week_data.get('queries')

        queries_qps = (week_data.get('queries') / self.maxQueryCount) * 100
        if queries_qps <= self.cdbtype1_rule.get('queries_qps'):
            x += 1
            ret['queries_qps'] = week_data.get('queries_qps')

        real_capacity = (week_data.get('real_capacity') / week_data.get('capacity')) * 100
        if real_capacity <= self.cdbtype1_rule.get('real_capacity'):
            x += 1
            ret['real_capacity'] = week_data.get('real_capacity')

        memory_use = (week_data.get('memory_use') / self.memory) * 100
        if memory_use <= self.cdbtype1_rule.get('memory_use'):
            x += 1
            ret['memory_use'] = week_data.get('memory_use')

        if x >= len(self.cdbtype1_rule):
            return ret
        else:
            return False


