#coding=utf-8
import logging
from datetime import datetime
from ops import db, login_manager
from flask import render_template, flash, request, jsonify, redirect, url_for, session, abort
from . import auth
from .forms import LoginForm, RegistForm
from ..models import Users
from flask_login import login_user, logout_user, login_required, current_user, fresh_login_required

# 日志
logger=logging.getLogger(__name__)


@login_manager.needs_refresh_handler
def refresh():
    flash('You have been logged out.')
    return redirect(url_for('.login'))


# “Post/ 重定向 /Get 模式”,提交登录密令的 POST 请求最后也做了重定向
# 重定向的地址有两种：
# 1、用户访问一个为授权的页面，会显示登录表单，Flask-login会把原地址保存在查询字符串的next参数中，
#    通过flask.request.args.get('next')访问。
# 2、回到主页面
@auth.route('/login/', methods=['GET', 'POST'])
def login():
    form = LoginForm()
    if form.validate_on_submit():
        username = form.username.data
        # password = form.password.data
        # Using session to check the user's login status
        # Add the user's name to cookie.
        # session['username'] = form.username.data
        user = Users.query.filter_by(username=username).first()
        """
        # 判断用户名是否存在
        if user is None:
            flash(u'用户不存在')
            return redirect(url_for('login'))
        # 判断密码是否正确
        if not user.check_password(password):
            flash(u'密码不正确')
            return redirect(url_for('login'))
        """
        # Using the Flask-Login to processing and check the login status for user
        # Remember the user's login status.
        # flask-login中的函数，在用户会话中把用户标记为已登录。如果想要实现"Remember me"功能，只需要传递remembeer=True即可。
        # 此时：一个cokkie即可保存到用户的电脑上，并且，如果userID没有在会话时，Flask-Login将自动从cookie中恢复。
        # 并且这个cookie是防修改的，如果用户尝试修改，这个cookie会被服务器丢弃。
        # 登录用户
        login_user(user, remember=False)
        # 保存用户的最后登录时间
        user.last_login = datetime.now()
        db.session.add(user)
        db.session.commit()
        flash("You have been logged in.", category="success")
        logger.info(u"用户：{0} 登录.".format(username))
        next_url = request.args.get('next')
        return redirect(next_url or url_for('cfm.set_conf_server'))
    return render_template('auth/login.html',
                           form=form,
                           model_name='login')


@auth.route('/regist/', methods=['GET', 'POST'])
def regist():
    """ 注册 """
    form = RegistForm()
    if form.validate_on_submit():
        user = form.regist()
        # 登录用户
        login_user(user)
        # 消息提示
        flash(u'注册成功')
        # 跳转到首页
        logger.info(u"用户：{0}，注册成功.".format(form.username.data))
        return redirect(url_for('.index'))
    return render_template('auth/regist.html', form=form)


@auth.route('/logout/')
@login_required
def logout():
    user = session['username']
    logger.debug(user)
    session.pop(user, None)
    logout_user() # 删除并重置用户会话，随后显示一条Flash消息
    flash('You have been logged out.')
    logger.info(u"用户：{0} 退出登录.".format(user))
    return redirect(url_for('.index'))

@auth.route('/')
@auth.route('/index/')
def index():
    # 判断用户是否已经登录
    return render_template('auth/index.html',
                           model_name='index')


