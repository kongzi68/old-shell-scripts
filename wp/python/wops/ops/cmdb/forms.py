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

from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, SubmitField, SelectField, HiddenField, FileField, TextAreaField
from wtforms.validators import DataRequired, ValidationError, Length

class ConfigServerForm(FlaskForm):
    """ 定义配置管理表单 """
    form_name = HiddenField('Form Name')
    game_id = SelectField(label=u"游戏版本", coerce=int, id='select_gameid')
    env = SelectField(label=u"SALT分组", id='select_env')
    submit = SubmitField(u'查  询')



