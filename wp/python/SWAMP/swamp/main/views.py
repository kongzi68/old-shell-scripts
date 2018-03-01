#coding=utf-8
import time
import logging
from .tools import Tools, ScriptsExec
from .forms import LoginForm, RegistForm, ScriptsForm
from .. import app, db, login_manager
from ..models import Users, Scripts
from .. import socketio
from settings import swamp_url
from datetime import datetime, timedelta
from swamp.main.libs.common import Prpcrypt
from flask_login import login_user, logout_user, login_required, current_user, fresh_login_required
from flask import render_template, flash, request, jsonify, redirect, url_for, session, abort
import Queue
from threading import Thread


log_queue1 = Queue.Queue()     # 临时脚本的日志队列
log_queue2 = Queue.Queue()    # web传的脚本，其运行日志队列
# 字符串解密与解密
secret_pass = Prpcrypt()
# 日志
logger=logging.getLogger(__name__)
# 设置登录页面的端点
login_manager.login_view = "login"
# LoginManager 对象的 session_protection 属性可以设为 None 、 'basic' 或 'strong'；设为 'strong' 时,
#+ Flask-Login 会记录客户端 IP地址和浏览器的用户代理信息,如果发现异动就登出用户。
login_manager.session_protection = "strong"
login_manager.login_message = "Please login to access this page."
login_manager.login_message_category = "info"
login_manager.remember_cookie_duration=timedelta(days=1)
login_manager.refresh_view = "login"
login_manager.needs_refresh_message = (
    u"To protect your account, please reauthenticate to access this page."
)
login_manager.needs_refresh_message_category = "info"

dict_run_script = {}



def get_scripts_id():
    ret = []
    for obj_item in Scripts.query.all():
        t_id = obj_item.id
        custom_name = obj_item.custom_name
        custom_name.encode('utf-8')
        ret.append((t_id, custom_name))
    return ret


def get_queue_log(user, log_queue, socket_name, msgsid):
    while True:
        time.sleep(0.2)
        try:
            tlog = log_queue.get(block=False)
            web_log = tlog.decode('utf-8')
            if tlog == 'normal_stop':
                if socket_name == 'show_web_scripts_log':
                    socketio.emit('scripts_stop', {'data': 'stop', 'msgsid': msgsid}, namespace='/test')
                    logger.error(u"normal_stop，send stop")
                break
            elif tlog == 'network_interruption':
                if socket_name == 'show_web_scripts_log':
                    session['net_stop'] = 'net_stop'
                    socketio.emit('scripts_stop', {'data': 'net_stop', 'msgsid': msgsid}, namespace='/test')
                    logger.error(u"network_interruption，send net_stop")
                break
            else:
                socketio.emit(socket_name, {'data': web_log, 'msgsid': msgsid}, namespace='/test')
            logger.info(u"{0};{1}".format(user, web_log))
        except Exception:
            # 队列为空的时候，直接pass掉
            pass
    logger.info(u'日志已显示完成')



@socketio.on('my_event', namespace='/test')
def handle_my_custom_event(msg):
    logger.error('received json: ' + str(msg))


@login_manager.user_loader
def load_user(user_id):
    """Load the user's info."""
    from swamp.models import Users
    return Users.query.filter_by(id=user_id).first()

@login_manager.needs_refresh_handler
def refresh():
    flash('You have been logged out.')
    return redirect(url_for('login'))

# “Post/ 重定向 /Get 模式”,提交登录密令的 POST 请求最后也做了重定向
# 重定向的地址有两种：
# 1、用户访问一个为授权的页面，会显示登录表单，Flask-login会把原地址保存在查询字符串的next参数中，
#    通过flask.request.args.get('next')访问。
# 2、回到主页面
@app.route('/', methods=['GET', 'POST'])
@app.route('/login/', methods=['GET', 'POST'])
def login():
    form = LoginForm()
    if form.validate_on_submit():
        username = form.username.data
        # password = form.password.data
        logger.debug(swamp_url.__to_string__(hide_password=False))   # 调试用
        # Using session to check the user's login status
        # Add the user's name to cookie.
        session['username'] = username
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
        return redirect(next_url or url_for('index'))
    return render_template('home/login.html',
                           form=form,
                           model_name='login')


@app.route('/regist/', methods=['GET', 'POST'])
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
        return redirect(url_for('index'))
    return render_template('home/regist.html', form=form)


@app.route('/logout/')
@login_required
def logout():
    user = session['username']
    logger.debug(user)
    session.pop(user, None)
    logout_user() # 删除并重置用户会话，随后显示一条Flash消息
    flash('You have been logged out.')
    logger.info(u"用户：{0} 退出登录.".format(user))
    return redirect(url_for('login'))


@app.route('/index_old/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def index_old():
    # 判断用户是否已经登录
    form = ScriptsForm()
    form.custom_name.choices = get_scripts_id()
    log_result = ''
    user = session['username']
    if request.method == 'POST':
        if form.validate_on_submit():
            id = form.custom_name.data
            pkg_name = form.pkg_name.data
            pkg_md5 = form.pkg_md5.data
            update_target = form.update_target.data
            scripts = Scripts.query.filter_by(id=id).first()
            custom_name = scripts.custom_name
            server_ip = scripts.server_ip
            server_user = scripts.server_user
            server_port = scripts.server_port
            server_password = secret_pass.decrypt(scripts.server_password)
            scripts_path = scripts.scripts_path
            scripts_name = scripts.scripts_name
            strings = u"{4};脚本及参数: {0},{1},{2},{3}".format(custom_name, pkg_name, pkg_md5, update_target, user)
            logger.info(strings)
            tools = Tools(server_ip, server_port, server_user, server_password)
            params = "{0};;{1};;{2}".format(pkg_name, pkg_md5, update_target)
            command = u"cd {0} && sh {1} '{2}'".format(scripts_path, scripts_name, params)
            logger.info(u"{0};{1}".format(user, command))
            log_result = tools.exec_command(command)
            log_result = log_result.decode('utf-8')
            flash(u'脚本已执行')
            logger.info(u"{0};{1}".format(user, log_result))
        else:
            log_result = u"form.validate_on_submit() `s value is flase"
            logger.error(log_result)
    return render_template('home/index_old.html',
                           form=form,
                           log_result=log_result,
                           model_name='index_old')


@app.route('/index/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def index():
    # 判断用户是否已经登录
    form = ScriptsForm()
    form.custom_name.choices = get_scripts_id()
    user = session['username']
    if request.method == 'POST':
        if form.validate_on_submit():
            id = form.custom_name.data
            session['script_id'] = id
            msgsid = form.msgsid.data
            session['msgsid'] = msgsid
            pkg_name = form.pkg_name.data
            pkg_md5 = form.pkg_md5.data
            update_target = form.update_target.data
            scripts = Scripts.query.filter_by(id=id).first()
            custom_name = scripts.custom_name
            server_ip = scripts.server_ip
            server_user = scripts.server_user
            server_port = scripts.server_port
            server_password = secret_pass.decrypt(scripts.server_password)
            scripts_path = scripts.scripts_path
            scripts_name = scripts.scripts_name
            scripts_log = scripts.scripts_log
            strings = u"{4};脚本及参数: {0},{1},{2},{3}".format(custom_name, pkg_name, pkg_md5, update_target, user)
            logger.info(strings)
            run_script = ScriptsExec(id, server_ip, server_port, server_user, server_password, scripts_log)
            params = "{0};;{1};;{2}".format(pkg_name, pkg_md5, update_target)
            command = u"cd {0} && sh {1} '{2}'".format(scripts_path, scripts_name, params)
            logger.info(u"{0};{1}".format(user, command))
            status = run_script.exec_scripts(command)
            if status == 'running':
                flash(u"脚本正在运行，处于锁定状态，请勿重复执行！")
                return redirect(url_for('index'))
            if status:
                logger.error("msgsid: {0}".format(msgsid))
                socketio.emit('scripts_start', {'data': 'start', 'msgsid': msgsid}, namespace='/test')
                # 取临时脚本的标准输出与标准错误输出日志
                thr1 = Thread(target=run_script.get_scripts_logs,
                              args=(1, run_script.log_name, log_queue1))
                thr1.start()
                # 取WEB需要被执行的脚本, 其自己创建脚本日志
                thr2 = Thread(target=run_script.get_scripts_logs,
                              args=(run_script.log_nums, run_script.log, log_queue2))
                thr2.start()
                time.sleep(2)
                flash(u'脚本开始执行')
                logger.info("start print log")
                thr3 = Thread(target=get_queue_log,
                              args=(user, log_queue1, 'show_temp_scripts_log', msgsid))
                thr3.start()
                thr4 = Thread(target=get_queue_log,
                              args=(user, log_queue2, 'show_web_scripts_log', msgsid))
                thr4.start()
                # flash(u'脚本')
                # logger.info("done")
            else:
                flash(u'脚本运行失败')
            # return redirect(url_for('index'))
        else:
            log_result = u"form.validate_on_submit() `s value is flase"
            logger.error(log_result)
    return render_template('home/index.html',
                           form=form,
                           model_name='index')


@app.route('/_get_web_scripts_log/',  methods=['GET', 'POST'])
def _get_web_scripts_log():
    targs = request.get_json()
    logger.error(targs)
    get_log = targs.get('data')
    net_stop = session.get('net_stop')
    if request.method == 'POST':
        logger.error("{0};;;{1}".format(get_log, net_stop))
        if get_log == 'get_log' and net_stop == 'net_stop':
            script_id = session.get('script_id')
            msgsid = session.get('msgsid')
            user = session.get('username')
            scripts = Scripts.query.filter_by(id=script_id).first()
            server_ip = scripts.server_ip
            server_user = scripts.server_user
            server_port = scripts.server_port
            server_password = secret_pass.decrypt(scripts.server_password)
            scripts_log = scripts.scripts_log
            log_nums = scripts.log_start_num
            run_script = ScriptsExec(script_id, server_ip, server_port, server_user, server_password, scripts_log)
            # 重新取WEB需要被执行的脚本日志
            thr1 = Thread(target=run_script.get_scripts_logs,
                          args=(log_nums, scripts_log, log_queue2))
            thr1.start()
            time.sleep(2)
            thr2 = Thread(target=get_queue_log,
                          args=(user, log_queue2, 'show_web_scripts_log', msgsid))
            thr2.start()
            logger.info(u"重新提取脚本运行日志记录")
            flash(u"重新提取脚本运行日志记录")
            return jsonify({'status': 'yes'})
        else:
            return jsonify({'status': 'no'})
    return redirect(url_for('index'))


@app.route('/admin/scripts/',  methods=['GET', 'POST'])
@login_required
def manage_scritps():
    pass
    return render_template('home/scripts_table.html',
                           model_name='manage_scritps')


@app.route('/admin/scripts/_scripts_table_data/')
@login_required
def _scripts_table_data():
    scripts = Scripts.query.all()
    total = len(scripts)
    # datas = jsonify(total=total, rows=[obj_item.to_json() for obj_item in scripts])
    datas = jsonify([obj_item.to_json() for obj_item in scripts])
    return datas


@app.route('/admin/scripts/_get_datas/', methods=['GET', 'POST'])
@login_required
def _get_datas():
    logger.debug(request.get_json())
    datas = request.get_json()
    t_datas = datas.get('datas')
    logger.debug(type(t_datas))
    logger.info(t_datas)
    # 需要添加对数据的验证
    # 添加新数据
    data = Scripts(
        custom_name=t_datas.get('custom_name'),
        server_ip=t_datas.get('server_ip'),
        server_user=t_datas.get('server_user'),
        server_port=t_datas.get('server_port'),
        server_password=secret_pass.encrypt(t_datas.get('server_password')),
        scripts_path=t_datas.get('scripts_path'),
        scripts_name=t_datas.get('scripts_name'),
        scripts_log=t_datas.get('scripts_log'))
    db.session.add(data)
    db.session.commit()
    return jsonify({'ret': True})


@app.route('/admin/scripts/_get_save_datas/', methods=['GET', 'POST'])
@login_required
def _get_save_datas():
    logger.debug(request.get_json())
    datas = request.get_json()
    t_datas = datas.get('datas')
    logger.debug(type(t_datas))
    logger.debug(t_datas)
    id = t_datas.get('id')
    # 更新修改
    ret = Scripts.query.filter_by(id=id).first()
    ret.custom_name = t_datas.get('custom_name')
    ret.server_ip = t_datas.get('server_ip')
    ret.server_user = t_datas.get('server_user')
    ret.server_port = t_datas.get('server_port')
    if ret.server_password != t_datas.get('server_password'):
        ret.server_password = secret_pass.encrypt(t_datas.get('server_password'))
    ret.scripts_path = t_datas.get('scripts_path')
    ret.scripts_name = t_datas.get('scripts_name')
    ret.scripts_log = t_datas.get('scripts_log')
    db.session.commit()
    return jsonify({'ret': True})


@app.route('/admin/scripts/_delete_datas/', methods=['GET', 'POST'])
@login_required
def _delete_datas():
    logger.debug(request.get_json())
    datas = request.get_json()
    id = datas.get('datas')
    logger.debug(type(id))
    logger.debug(id)
    Scripts.query.filter_by(id=id).delete()
    db.session.commit()
    return jsonify({'ret': True})

@app.route('/admin/_clean_scripts_status/', methods=['GET', 'POST'])
@login_required
def _clean_scripts_status():
    logger.debug(request.get_json())
    datas = request.get_json()
    id = datas.get('data')
    logger.debug(type(id))
    logger.debug(id)
    ret = Scripts.query.filter_by(id=id).first()
    ret.status = 0
    db.session.commit()
    return jsonify({'ret': True})

