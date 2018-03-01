#!/usr/bin/python
# -*- coding: utf-8 -*-

from base import Base

class Feecenter(Base):
    requestHost = 'feecenter.api.qcloud.com'

def main():
    action = 'DescribeResourceBills'
    config = {
        'Region': 'gz',
        'secretId': '你的secretId',
        'secretKey': '你的secretKey',
        'method': 'get'
    }
    params = {}
    service = Feecenter(config)
    print service.call(action, params)

if (__name__ == '__main__'):
    main()