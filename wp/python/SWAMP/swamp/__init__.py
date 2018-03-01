#coding=utf-8

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from flask_bcrypt import Bcrypt
from flask_assets import Environment, Bundle
from flask_socketio import SocketIO

app = Flask(__name__)
app.config.from_object('settings')
db = SQLAlchemy(app)
db.init_app(app)
socketio = SocketIO()
socketio.init_app(app)
login_manager = LoginManager()
login_manager.init_app(app)
bcrypt = Bcrypt(app)
assets_env = Environment()
# main_css = Bundle('bootstrap-table/dist/bootstrap-table.css', 'bootstrap/css/bootstrap.min.css',
                  # filters='cssmin', output='assets/css/common.css')
main_js = Bundle('js/jquery.min.js', 'bootstrap/js/bootstrap.min.js', 'js/scripts_table.js',
                 'bootstrap-table/dist/bootstrap-table.js', 'bootstrap-table/dist/locale/bootstrap-table-zh-CN.js',
                 filters='jsmin', output='assets/js/common.js')
assets_env.init_app(app)
assets_env.register('main_js', main_js)
# assets_env.register('main_css', main_css)

from main import views
