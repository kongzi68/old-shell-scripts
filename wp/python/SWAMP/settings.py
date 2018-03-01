#!/usr/bin/python
#coding=utf-8
from swamp.main.libs.libdb import swamp
from sqlalchemy.engine.url import URL

"""
Flask配置文件

参考文档：
http://flask.pocoo.org/docs/0.11/config/
http://docs.jinkan.org/docs/flask/config.html
"""

# cmdb库
swamp_url = URL('mysql+pymysql',
                username=swamp['user'],
                password=swamp['passwd'],
                host=swamp['host'],
                port=swamp['port'],
                database=swamp['dbname'])

# 数据库
# swamp_url 对象类型为 class
# SQLALCHEMY_DATABASE_URI = swamp_url
# 因 flask_migrate 需要的 SQLALCHEMY_DATABASE_URI 数据类型为字符串
SQLALCHEMY_DATABASE_URI = swamp_url.__to_string__(hide_password=False)
# SQLALCHEMY_DATABASE_URI = "mysql+pymysql://root:123456@192.168.10.36:3306/swamp?charset=utf8"

# 密钥
SECRET_KEY = 'SDf84mRTZirQpisTbK5ukBhir1VTqQCA'

SQLALCHEMY_TRACK_MODIFICATIONS = True

# 调试模式
DEBUG = True
# 测试模式
TESTING = True