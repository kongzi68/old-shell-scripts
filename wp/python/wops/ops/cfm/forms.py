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


class TestForm(FlaskForm):
    """ 定义登录表单 """
    username = StringField(label='UserName', validators=[DataRequired(u"请输入用户名")],
        description=u"请输入用户名",
        render_kw={"required": "required", "class": "form-controal"})
    password = PasswordField('Password', validators=[DataRequired()])
    submit = SubmitField(u'登  录')


class ConfigServerForm(FlaskForm):
    """ 定义配置管理表单 """
    form_name = HiddenField('Form Name')
    game_id = SelectField(label=u"游戏版本", coerce=int, id='select_gameid')
    env = SelectField(label=u"SALT分组", id='select_env')
    submit = SubmitField(u'查  询')


class ConfigUploadForm(FlaskForm):
    """ 文件上传 """
    form_name = HiddenField('Form Name')
    custom_name = StringField(label=u'配置文件分发组名',
        validators=[DataRequired()],
        render_kw={"required": 'required',
                   "class": "form-control",
                   "placeholder": u"请输入这组配置文件的名称，用于自我识别"})
    conf_template = FileField(label=u"配置文件模版上传",
        validators=[DataRequired()],
        render_kw={"required": 'required',
                   "class": "form-control"})
    conf_data = TextAreaField(label=u"配置文件动态数据",
        validators=[DataRequired()],
        render_kw={"required": 'required',
                   "class": "form-control",
                   "rows": 10,
                   "placeholder": ur"请输入配置文件动态数据，示例：13799ff4c8113a06,C:\3JianHaoServer01\Data\Config\ServerConfig.xml,10100211,203.195.193.234,10022,202服 万水千山,10.232.62.11,3306,ProjectM;13799ff4c8113a06,C:\3JianHaoServer02\Data\Config\ServerConfig.xml,10100212,203.195.193.234,10023,203服 风流倜傥,10.232.62.11,3306,ProjectM;"})


class ConfigQueryForm(FlaskForm):
    """ 定义配置管理表单 """
    form_name = HiddenField('Form Name')
    game_id = SelectField(label=u"游戏版本", coerce=int, id='select_gameid')
    submit = SubmitField(u'查  询')


class UploadForm(FlaskForm):
    """ 文件上传 """
    conf_template = FileField(label=u"配置文件模版上传", validators=[DataRequired()],
        render_kw={"required": 'required', "class": "form-control"})


