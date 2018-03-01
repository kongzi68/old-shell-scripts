# coding: utf-8
from swamp import db
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from swamp.main.constants import PermsEnum, UserStatusEnum


class Users(UserMixin, db.Model):
    """ 用户 """
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    status = db.Column(db.Enum(UserStatusEnum))
    is_valid = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime)
    updateed_at = db.Column(db.DateTime)
    last_login = db.Column(db.DateTime, doc=u"最后登录时间")

    def set_password(self, password):
        """  设置用户的hash密码 """
        self.password = generate_password_hash(password)

    def check_password(self, password):
        """ 验证用户的password """
        return check_password_hash(self.password, password)

    def __repr__(self):
        return self.username


class Roles(db.Model):
    """ 角色 """
    __tablename__ = 'roles'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    perms = db.Column(db.Enum(PermsEnum))
    is_valid = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime)
    updateed_at = db.Column(db.DateTime)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))

    def __repr__(self):
        return '<Role %r>' % self.name


class Scripts(db.Model):
    """ 脚本列表 """
    __tablename__ = 't_scripts'
    id = db.Column(db.Integer, primary_key=True)
    custom_name = db.Column(db.String(200))
    server_ip = db.Column(db.String(15, u'utf8_bin'), nullable=False)
    server_user = db.Column(db.String(20, u'utf8_bin'), nullable=False)
    server_port = db.Column(db.Integer)
    server_password = db.Column(db.String(200), nullable=False)
    scripts_path = db.Column(db.Text(collation=u'utf8_bin'))
    scripts_name = db.Column(db.Text(collation=u'utf8_bin'))
    scripts_log = db.Column(db.String(200))
    status = db.Column(db.Boolean, default=False)
    log_start_num = db.Column(db.Integer)

    def to_json(self):
        json_scripts = {
            'id': self.id,
            'custom_name': self.custom_name,
            'server_ip': self.server_ip,
            'server_user': self.server_user,
            'server_port': self.server_port,
            'server_password': self.server_password,
            'scripts_path': self.scripts_path,
            'scripts_name': self.scripts_name,
            'scripts_log': self.scripts_log
        }
        return json_scripts

    def __repr__(self):
        return '<Scripts %r>' % self.custom_name















