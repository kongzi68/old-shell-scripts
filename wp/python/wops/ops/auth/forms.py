#coding=utf-8

"""
表单类
参考文档：http://wtforms.readthedocs.io/en/latest/
http://wtforms.readthedocs.io/en/latest/genindex.html

字段类型            说明
StringField         文本字段
TextAreaField       多行文本字段
PasswordField       密码文本字段
HiddenField         隐藏文本字段
DateField           文本字段，值为datetime.date格式
DateTimeField       文本字段，值为datetime.datetime格式
IntegerField        文本字段，值为整数
DecimalField        文本字段，值为decimal.Decimal
FloatField          文本字段，值为浮点数
BooleanField        复选框，值为True和False
RadioField          一组单选框
SelectField         下拉列表
SelectMultipleField 下拉列表，可选择多个值
FileField           文件上传字段
SubmitField         表单提交按钮
FormField           把表单作为字段嵌入另一个表单
FieldList           一组指定类型的字段
"""
import logging
from datetime import datetime
from ops import db
from ..models import Users
from flask_wtf import FlaskForm
from flask import session
from wtforms import StringField, PasswordField, SubmitField, SelectField, HiddenField, FileField, TextAreaField
from wtforms.validators import DataRequired, ValidationError


logger = logging.getLogger(__name__)


class LoginForm(FlaskForm):
    """ 登录表单 """
    username = StringField(label='UserName', validators=[DataRequired(u"请输入用户名")],
                           description=u"请输入用户名",
                           render_kw={"required": "required",
                                      "class": "form-control",
                                      "placeholder": u"用户名"})
    password = PasswordField(label='PassWord', validators=[DataRequired(u"请输入密码")],
                             description=u"请输入密码",
                             render_kw={"required": "required",
                                        "class": "form-control",
                                        "placeholder": u"密码"})
    submit = SubmitField('Sign in', render_kw={'class': 'btn btn-default' })

    def validate_password(self, field):
        password = field.data
        logger.debug(str(password))
        username = session['username']
        if username:
            logger.debug(username)
            user = Users.query.filter_by(username=username).first()
            if not user.check_password(password):
                raise ValidationError(u"密码不正确")
            return password

    def validate_username(self, field):
        username = field.data.lower()
        logger.debug(username)
        user = Users.query.filter_by(username=username).first()
        logger.debug(type(user))
        logger.debug(user)
        if user:
            session['username'] = username
        else:
            session['username'] = ''
            raise ValidationError(u"用户名不存在")


class RegistForm(FlaskForm):
    """ 用户注册 """
    username = StringField(label='UserName', validators=[DataRequired(u"请输入用户名")],
        description=u"请输入用户名",
        render_kw={"required": "required",
                   "class": "form-control",
                   "placeholder": u"用户名"})
    password = PasswordField(label='PassWord', validators=[DataRequired(u"请输入密码")],
        description=u"请输入密码",
        render_kw={"required": "required",
                   "class": "form-control",
                   "placeholder": u"密码"})
    submit = SubmitField('Sign up', render_kw={'class': 'btn btn-default'})

    def validate_password(self, field):
        password = field.data
        # logger.debug(str(password))
        if len(password) < 6:
            raise ValidationError(u"密码必须大于6位")
        return password

    def validate_username(self, field):
        username = field.data.lower()
        # 判断改用户名是否已经存在
        user = Users.query.filter_by(username=username).first()
        if user is not None:
            raise ValidationError(u"该用户已经注册")
        return username

    def regist(self):
        """ 注册用户 """
        data = self.data
        users = Users(
            username=data['username'],
            created_at=datetime.now()
            )
        # 设置用户的密码
        users.set_password(data['password'])
        db.session.add(users)
        db.session.commit()
        # 保存用户数据
        # 返回用户
        return users