#coding=utf-8
import os
from ops.libs.libdb import cmdb, cmdb_oss, cmdb_web
from sqlalchemy.engine.url import URL
basedir = os.path.abspath(os.path.dirname(__file__))


class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'MqUYFVXFZkQeZoEx9WRLrLYSs9igvsOmCuun1KmZ'
    SSL_REDIRECT = False
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_RECORD_QUERIES = True
    FLASKY_POSTS_PER_PAGE = 20
    FLASKY_FOLLOWERS_PER_PAGE = 50
    FLASKY_COMMENTS_PER_PAGE = 30
    FLASKY_SLOW_DB_QUERY_TIME = 0.5
    # cmdb库
    cmdb_engine_url = URL('mysql+pymysql',
                          username=cmdb['user'],
                          password=cmdb['passwd'],
                          host=cmdb['host'],
                          port=cmdb['port'],
                          database=cmdb['dbname'])
    # cmdb_oss库
    cmdb_oss_engine_url = URL('mysql+pymysql',
                              username=cmdb_oss['user'],
                              password=cmdb_oss['passwd'],
                              host=cmdb_oss['host'],
                              port=cmdb_oss['port'],
                              database=cmdb_oss['dbname'])
    # cmdb_web库
    cmdb_web_engine_url = URL('mysql+pymysql',
                              username=cmdb_web['user'],
                              password=cmdb_web['passwd'],
                              host=cmdb_web['host'],
                              port=cmdb_web['port'],
                              database=cmdb_web['dbname'])
    # 数据库
    """
    # cmdb_web_engine_url 对象类型为 class
    # SQLALCHEMY_DATABASE_URI = cmdb_web_engine_url
    # 因 flask_migrate 需要的 SQLALCHEMY_DATABASE_URI 数据类型为字符串
    # SQLALCHEMY_DATABASE_URI = "mysql+pymysql://IamUsername:123456@iamIPaddress:3306/cmdb_web?charset=utf8"
    SQLALCHEMY_DATABASE_URI = cmdb_web_engine_url
    SQLALCHEMY_BINDS = {
        'cmdb': cmdb_engine_url,
        'cmdb_oss': cmdb_oss_engine_url}
    """
    SQLALCHEMY_DATABASE_URI = cmdb_web_engine_url.__to_string__(hide_password=False)
    SQLALCHEMY_BINDS = {
        'cmdb': cmdb_engine_url.__to_string__(hide_password=False),
        'cmdb_oss': cmdb_oss_engine_url.__to_string__(hide_password=False)}

    @classmethod
    def init_app(cls, app):
        pass


class DevelopmentConfig(Config):
    DEBUG = True


class TestingConfig(Config):
    TESTING = True
    WTF_CSRF_ENABLED = False


class ProductionConfig(Config):
    @classmethod
    def init_app(cls, app):
        Config.init_app(app)


config = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}
