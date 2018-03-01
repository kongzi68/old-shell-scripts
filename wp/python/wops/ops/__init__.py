#coding=utf-8
from datetime import timedelta
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from config import config



db = SQLAlchemy()

login_manager = LoginManager()
# 设置登录页面的端点
login_manager.login_view = 'auth.login'
# LoginManager 对象的 session_protection 属性可以设为 None 、 'basic' 或 'strong'；设为 'strong' 时,
#+ Flask-Login 会记录客户端 IP地址和浏览器的用户代理信息,如果发现异动就登出用户。
login_manager.session_protection = "strong"
login_manager.login_message = "Please login to access this page."
login_manager.login_message_category = "info"
login_manager.remember_cookie_duration=timedelta(days=1)
login_manager.refresh_view = "login"
login_manager.needs_refresh_message = (
    "To protect your account, please reauthenticate to access this page."
)
login_manager.needs_refresh_message_category = "info"


def create_app(config_name):
    app = Flask(__name__)
    app.config.from_object(config[config_name])
    config[config_name].init_app(app)

    db.init_app(app)
    login_manager.init_app(app)

    if app.config['SSL_REDIRECT']:
        from flask_sslify import SSLify
        sslify = SSLify(app)

    from .auth import auth as auth_blueprint
    app.register_blueprint(auth_blueprint)

    from .cfm import cfm as cfm_blueprint
    app.register_blueprint(cfm_blueprint, url_prefix='/cfm')

    from .cmdb import cmdb as cmdb_blueprint
    app.register_blueprint(cmdb_blueprint, url_prefix='/cmdb')


    """
    from .api import api as api_blueprint
    app.register_blueprint(api_blueprint, url_prefix='/api/v1')
    """

    return app

