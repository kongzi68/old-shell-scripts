# coding: utf-8
from . import db, login_manager
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from .libs.constants import UserStatusEnum


class Users(UserMixin, db.Model):
    """
    用户
    不指定 __bind_key__ 的话，这个表使用配置：SQLALCHEMY_DATABASE_URI
    """
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


class TCdb(db.Model):
    __tablename__ = 't_cdb'
    __bind_key__ = 'cmdb'

    uInstanceId = db.Column(db.String(30, u'utf8_bin'), primary_key=True)
    cdbInstanceName = db.Column(db.String(50, u'utf8_bin'))
    cdbInstanceVip = db.Column(db.String(15, u'utf8_bin'))
    cdbInstanceVport = db.Column(db.Integer)
    memory = db.Column(db.Integer)
    volume = db.Column(db.Integer)
    cdbInstanceType = db.Column(db.Integer)
    status = db.Column(db.Integer)
    engineVersion = db.Column(db.String(10, u'utf8_bin'))
    price = db.Column(db.Float(8), server_default=db.text("'0.00'"))
    maxQueryCount = db.Column(db.Integer)


class TDbserver(db.Model):
    __tablename__ = 't_dbserver'
    __bind_key__ = 'cmdb'

    db_id = db.Column(db.String(16, u'utf8_bin'), primary_key=True)
    server_id = db.Column(db.String(16, u'utf8_bin'))
    address = db.Column(db.String(50, u'utf8_bin'))
    port = db.Column(db.Integer)
    bind_db_id = db.Column(db.String(16, u'utf8_bin'))
    db_relation = db.Column(db.String(6, u'utf8_bin'))
    version = db.Column(db.String(10, u'utf8_bin'))
    db_type = db.Column(db.String(15, u'utf8_bin'))
    db_names = db.Column(db.String(collation=u'utf8_bin'))


class TGametype(db.Model):
    __tablename__ = 't_gametype'
    __bind_key__ = 'cmdb'

    game_id = db.Column(db.Integer, primary_key=True)
    game = db.Column(db.String(20, u'utf8_bin'))
    type = db.Column(db.String(20, u'utf8_bin'))

    def to_json(self):
        json_ret = {
            'game_id': self.game_id,
            'game': self.game,
            'type': self.type
        }
        return json_ret


class TG(db.Model):
    __tablename__ = 't_gs'
    __bind_key__ = 'cmdb'

    gs_id = db.Column(db.String(16, u'utf8_bin'), primary_key=True, server_default=db.text("''"))
    server_id = db.Column(db.String(16, u'utf8_bin'))


class TPingfailure(db.Model):
    __tablename__ = 't_pingfailure'
    __bind_key__ = 'cmdb'
    __table_args__ = (
        db.Index('t_index_01', 'server_id', 'times', unique=True),
    )

    server_id = db.Column(db.String(16, u'utf8_bin'), primary_key=True)
    times = db.Column(db.Integer, server_default=db.text("'0'"))


class TProgram(db.Model):
    __tablename__ = 't_program'
    __bind_key__ = 'cmdb'
    __table_args__ = (
        db.Index('t_index_01', 'program_id', 'server_id', unique=True),
    )

    program_id = db.Column(db.String(16, u'utf8_bin'), primary_key=True)
    server_id = db.Column(db.String(16, u'utf8_bin'))
    program = db.Column(db.String(30, u'utf8_bin'))
    program_path = db.Column(db.Text(collation=u'utf8_bin'))
    address = db.Column(db.String(50, u'utf8_bin'))
    pid = db.Column(db.Integer)
    port = db.Column(db.Integer)
    status = db.Column(db.Integer, nullable=False, server_default=db.text("'1'"))


class TServer(db.Model):
    __tablename__ = 't_server'
    __bind_key__ = 'cmdb'
    __table_args__ = (
        db.Index('t_index_01', 'server_id', 'game_id', unique=True),
    )

    server_id = db.Column(db.String(16, u'utf8_bin'), primary_key=True)
    game_id = db.Column(db.Integer)
    hostname = db.Column(db.String(50, u'utf8_bin'))
    ip = db.Column(db.String(15, u'utf8_bin'))
    netip = db.Column(db.String(15, u'utf8_bin'))
    os = db.Column(db.String(80, u'utf8_bin'))
    cpu = db.Column(db.String(80, u'utf8_bin'))
    mem = db.Column(db.Integer)
    disk = db.Column(db.Integer)
    status = db.Column(db.Integer, server_default=db.text("'1'"))
    env = db.Column(db.String(30, u'utf8_bin'))
    saltid = db.Column(db.String(50, u'utf8_bin'))
    uninstanceid = db.Column(db.String(20, u'utf8_bin'))
    price = db.Column(db.Float(6))
    cvmtype = db.Column(db.String(20, u'utf8_bin'))

    def to_json(self):
        json_ret = {
            'server_id': self.server_id,
            'game_id': self.game_id,
            'hostname': self.hostname,
            'ip': self.ip,
            'netip': self.netip,
            'os': self.os,
            'cpu': self.cpu,
            'mem': self.mem,
            'disk': self.disk,
            'status': self.status,
            'env': self.env,
            'saltid': self.saltid,
            'uninstanceid': self.uninstanceid,
            'price': self.price,
            'cvmtype': self.cvmtype
        }
        return json_ret


class TSaltMaster(db.Model):
    __tablename__ = 't_saltmaster'
    __bind_key__ = 'cmdb'

    game_id = db.Column(db.Integer, primary_key=True)
    server_id = db.Column(db.String(16, u'utf8_bin'))


class TConfig(db.Model):
    __tablename__ = 't_config'
    __bind_key__ = 'cmdb_oss'

    id = db.Column(db.String(16, u'utf8_bin'), primary_key=True)
    game_id = db.Column(db.Integer)
    custom_name = db.Column(db.String(100, u'utf8_bin'))
    servers = db.Column(db.Text(collation=u'utf8_bin'))
    conf_name = db.Column(db.String(100, u'utf8_bin'))
    conf_save_name = db.Column(db.String(100, u'utf8_bin'))
    conf_data = db.Column(db.Text(collation=u'utf8_bin'))

    def to_json(self):
        json_ret = {
            'id': self.id,
            'game_id': self.game_id,
            'custom_name': self.custom_name,
            'servers': self.servers,
            'conf_name': self.conf_name,
            'conf_save_name': self.conf_save_name,
            'conf_data': self.conf_data
        }
        return json_ret


class TConfigDict(db.Model):
    __tablename__ = 't_config_dict'
    __bind_key__ = 'cmdb_oss'

    id = db.Column(db.Integer, primary_key=True)
    conf_id = db.Column(db.String(16, u'utf8_bin'))
    server_id = db.Column(db.String(16, u'utf8_bin'))
    conf_path = db.Column(db.String(200, u'utf8_bin'))


@login_manager.user_loader
def load_user(user_id):
    # return Users.query.get(int(user_id))
    return Users.query.filter_by(id=user_id).first()

