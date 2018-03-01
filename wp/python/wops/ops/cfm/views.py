#coding=utf-8
import config
import logging
import os
from . import cfm
from .conf_tools import CreateSLS
from .forms import ConfigServerForm, ConfigUploadForm, ConfigQueryForm, UploadForm
from ..models import TServer, TConfig, TConfigDict, TGametype
from ..libs.common import getID, rename_file
from ops import db
from flask import render_template, flash, request, jsonify, redirect, url_for, session
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from flask_login import login_required, fresh_login_required


logger = logging.getLogger(__name__)

# 文件上传的目录
UPLOAD_PATH = os.path.join(config.basedir, 'static/medias')

engine = create_engine(config.Config.cmdb_oss_engine_url, echo=True)
DB_dict_global = sessionmaker(bind=engine)


def get_gameid():
    ret = []
    for obj_item in TGametype.query.all():
        gameid = obj_item.game_id
        game = obj_item.game
        g_type = obj_item.type

        if game and g_type:
            gametype = game + g_type
        elif game and (not g_type):
            gametype = game
        elif (not game) and g_type:
            gametype = g_type
        else:
            gametype = 'null'
        gametype.encode('utf-8')
        ret.append((gameid, gametype))
    return ret

def get_model_field(model, field):
    try:
        attr = getattr(model, field)
    except AttributeError:
        try:
            attr = getattr(model, field)
        except AttributeError:
            raise AttributeError('Could not find attribute or method '
                                 'named "%s".' % field)
        else:
            return attr(model)
    else:
        if callable(attr):
            attr = attr()
        return attr

def get_salt_group(game_id):
    ret = []
    t_ret = set()  # 集合去重
    for obj_item in TServer.query.filter_by(game_id=game_id).all():
        envs = obj_item.env
        for env in envs.split(','):
            t_ret.add(env)
    for item in t_ret:
        ret.append((item, item))
    return ret

def check_configid(configid):
    if configid is None:
        flash(u"获取配置文件ID错误，请重新选择。")
        return False
    t_num = configid.split(',').__len__()
    if t_num >= 2:
        flash(u"每次只能选择一条数据，请重新选择。")
        return False
    else:
        return True


@cfm.route('/', methods=['GET', 'POST'])
@cfm.route('/server/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def set_conf_server():
    form = ConfigServerForm(form_name='ConfigServerForm')
    form.game_id.choices = get_gameid()
    game_id = form.game_id.data
    if game_id:
        session['gameid'] = game_id
    else:
        session['gameid'] = None
    # logger.debug(session['gameid'])
    form.env.choices = get_salt_group(game_id)
    env = form.env.data
    if env:
        session['salt_group'] = env
    else:
        session['salt_group'] = None
    # 在这个页面时，清空serverids
    session['serverids'] = None
    return render_template('cfm/conf_servers.html',
                           get_model_field=get_model_field,
                           model_name='.set_conf_server',
                           form=form)


@cfm.route('/api/_api_table_data_tserver/')
@login_required
def _api_table_data_tserver():
    salt_group = session['salt_group']
    gameid = session['gameid']
    logger.debug("GAMEID: {0};;SALT_GROUP: {1}".format(gameid, salt_group))
    if salt_group and gameid:
        page_data = TServer.query.filter(TServer.env.like('%{0}%'.format(salt_group)),
                                         TServer.game_id==gameid).all()
    else:
        page_data = TServer.query.all()
    datas = jsonify([obj_item.to_json() for obj_item in page_data])
    return datas


@cfm.route('/api/_api_table_data_tconfig/')
@login_required
def _api_table_data_tconfig():
    gameid = session['gameid']
    logger.debug("GAMEID: {0}".format(gameid))
    if gameid:
        page_data = TConfig.query.filter_by(game_id=gameid).all()
    else:
        page_data = TConfig.query.all()
    datas = jsonify([obj_item.to_json() for obj_item in page_data])
    return datas



@cfm.route('/manage/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def set_conf_manage():
    form = ConfigUploadForm(form_name='ConfigUploadForm')
    serverids = session.get('serverids')
    gameid = session.get('gameid')
    if not serverids:
        logger.debug(serverids)
        flash(u"The server_id is null, Please select again.")
        return redirect(url_for('.set_conf_server'))
    if not gameid:
        logger.debug(serverids)
        flash(u"The game_id is null, Please select again.")
        return redirect(url_for('.set_conf_server'))
    if form.validate_on_submit():
        conf_template = form.conf_template.data
        conf_filename = conf_template.filename
        custom_name = form.custom_name.data
        conf_data = form.conf_data.data
        n_id = getID(gameid, serverids, conf_filename)
        logger.debug("{0};{1};{2}".format(gameid, serverids, conf_filename))
        filename_split = conf_filename.split('.')
        re_name = "{0}.{1}".format(n_id, filename_split[-1])
        ret = TConfig.query.filter_by(id=n_id).first()
        if ret:
            o_custom_name = ret.custom_name
            if o_custom_name != custom_name:
                ret.custom_name = custom_name
            o_conf_data = ret.conf_data
            if o_conf_data != conf_data:
                ret.conf_data = conf_data
            db.session.commit()
            flash(u'更新数据成功.')
        else:
            t_data = TConfig(
                id=n_id,
                game_id=session['gameid'],
                servers=session['serverids'],
                custom_name=custom_name,
                conf_name=conf_filename,
                conf_save_name=re_name,
                conf_data=conf_data)
            # 把配置文件相应的数据保存到cmdb_oss库的t_config表
            db.session.add(t_data)
            db.session.commit()
            flash(u'新数据保存成功.')
        # 无论是更新还是保存，都重新上传保存一次文件
        # 文件的全路径
        logger.debug(UPLOAD_PATH)
        if not os.path.exists(UPLOAD_PATH):
            os.makedirs(UPLOAD_PATH)
        filename = os.path.join(UPLOAD_PATH, conf_filename)
        logger.debug(filename)
        conf_template.save(filename)
        rename_file(UPLOAD_PATH, conf_filename, re_name)
        session['configid'] = n_id
    return render_template('cfm/conf_manage.html',
                           model_name='.set_conf_manage',
                           form=form)


@cfm.route('/query/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def set_conf_query():
    form = ConfigQueryForm(form_name='ConfigQueryForm')
    form.game_id.choices = get_gameid()
    session['gameid'] = form.game_id.data
    return render_template('cfm/conf_query.html',
                           get_model_field=get_model_field,
                           model_name='.set_conf_query',
                           form=form)


@cfm.route('/upload/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def conf_upload():
    """ 文件上传 """
    if not check_configid(session['configid']):
        return redirect(url_for('.set_conf_query'))
    form = UploadForm()
    if form.validate_on_submit():
        conf_template = form.conf_template.data
        conf_filename = conf_template.filename
        filename_split = conf_filename.split('.')
        re_name = "{0}.{1}".format(session['configid'], filename_split[-1])
        logger.debug(UPLOAD_PATH)
        if not os.path.exists(UPLOAD_PATH):
            os.makedirs(UPLOAD_PATH)
        if conf_template:
            # 文件的全路径
            filename = os.path.join(UPLOAD_PATH, conf_filename)
            logger.debug(filename)
            conf_template.save(filename)
            rename_file(UPLOAD_PATH, conf_filename, re_name)
            flash(u"文件上传成功")
    return render_template("cfm/upload.html",
                           form=form,
                           model_name='.set_conf_query')

@cfm.route('/cat_details/', methods=['GET', 'POST'])
@cfm.route('/cat_details/<int:pk>/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def conf_cat_details(pk=1):
    """ 查看配置文件内容 """
    if not check_configid(session['configid']):
        return redirect(url_for('.set_conf_query'))
    t_config_dict = TConfigDict.query.filter_by(id=pk).first()
    server_id = t_config_dict.server_id
    conf_path = t_config_dict.conf_path
    conf_id = t_config_dict.conf_id
    try:
        t_server = TServer.query.filter_by(server_id=server_id).first()
        saltid = t_server.saltid
        logger.debug(conf_path)
        logger.debug(saltid)
        new_sls = CreateSLS(conf_id)
        result = new_sls.get_config(saltid, conf_path)
        logger.debug(result)
        return render_template("cfm/conf_cat_details.html",
                               model_name='.conf_cat_table',
                               result=result.decode('utf-8'),
                               conf_path=conf_path)
    except Exception as err:
        logger.error(err)
        flash(u"{0}".format(err))
        return redirect(url_for('.set_conf_query'))


@cfm.route('/cat_table/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def conf_cat_table():
    """ 查看配置文件内容 """
    if not check_configid(session['configid']):
        return redirect(url_for('.set_conf_query'))
    # 运行之前，先清空表数据，以及恢复ID自增长为1
    # db.dict_global.query(TConfigDict).delete()
    # db.dict_global.commit()
    db_session = DB_dict_global()
    db_session.execute("DELETE FROM t_config_dict;")
    db_session.execute('TRUNCATE TABLE t_config_dict;')
    db_session.commit()
    db_session.close()
    # 把新的数据写入到表
    try:
        t_config = TConfig.query.filter_by(id=session['configid']).first()
        conf_id = t_config.id
        t_dict = CreateSLS.strings_to_dict(t_config.conf_data)
        logger.debug(str(t_dict))
        for server_id in t_dict.keys():
            for item in t_dict.get(server_id):
                conf_path = item[0]
                t_data = TConfigDict(
                    conf_id=conf_id,
                    server_id=server_id,
                    conf_path=conf_path
                )
                db.session.add(t_data)
                db.session.commit()
    except Exception:
        return redirect(url_for('.set_conf_query'))
    # 从表中取出新的数据
    titles = ['id', 'conf_id', 'server_id', 'conf_path']
    page_data = TConfigDict.query.all()
    return render_template("cfm/conf_cat_table.html",
                           page_data=page_data,
                           titles=titles,
                           get_model_field=get_model_field,
                           model_name='.set_conf_query')


@cfm.route('/_get_salt_group/')
@login_required
@fresh_login_required
def _get_salt_group():
    logger.debug(str(request.args))
    game_id = request.args.get('game_id', 'game_id', type=str)
    logger.debug(str(game_id))
    env = get_salt_group(game_id)
    return jsonify(env)

@cfm.route('/_get_serverids/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def _get_serverids():
    logger.debug(request.get_json())
    serverids = request.get_json()
    t_serverids = serverids.get('serverids')
    if t_serverids:
        session['serverids'] = t_serverids
    else:
        session['serverids'] = None
    logger.info(session['serverids'])
    return jsonify({'ok': True})

@cfm.route('/_get_id/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def _get_id():
    id = request.get_json()
    t_id = id.get('id')
    if t_id:
        session['configid'] = t_id
    else:
        session['configid'] = None
    logger.info(session['configid'])
    return jsonify({'ok': True})

@cfm.route('/create_sls/', methods=['GET', 'POST'])
@login_required
def create_sls():
    """ 创建SLS """
    if not check_configid(session['configid']):
        return redirect(url_for('.set_conf_query'))
    new_sls = CreateSLS(session['configid'])
    new_sls.push_sls()
    logger.info(u'生成SLS文件成功')
    flash(u'创建SLS成功。')
    return redirect(url_for('.set_conf_query'))

@cfm.route('/_create_sls/', methods=['GET', 'POST'])
@login_required
def _create_sls():
    """ 创建SLS """
    if request.method == 'POST' and session['configid'] is not None:
        new_sls = CreateSLS(session['configid'])
        new_sls.push_sls()
        logger.info(u'生成SLS文件成功')
        logs = u'创建SLS成功。'
    else:
        logger.error(u'创建SLS文件失败，请检查.')
        logs = u'创建SLS失败，请检查。'
    return logs

@cfm.route('/test_push_sls/', methods=['GET', 'POST'])
@login_required
def test_push_sls():
    """ 测试推送配置文件到minion端 """
    if not check_configid(session['configid']):
        return redirect(url_for('.set_conf_query'))
    new_sls = CreateSLS(session['configid'])
    logs = new_sls.push_config()
    logger.info(u'测试推送配置文件到minion端')
    logger.info(logs)
    flash(u'测试推送配置文件到minion端')
    return redirect(url_for('.set_conf_query'))

@cfm.route('/_test_push_sls/', methods=['GET', 'POST'])
@login_required
def _test_push_sls():
    """ 测试推送配置文件到minion端 """
    logs = ''
    if request.method == 'POST' and session['configid'] is not None:
        new_sls = CreateSLS(session['configid'])
        logs = new_sls.push_config()
        logger.info(u'测试推送配置文件到minion端')
    else:
        logger.error(u'测试推送配置文件到minion端失败，请检查.')
    return logs

@cfm.route('/push_sls/', methods=['GET', 'POST'])
@login_required
def push_sls():
    """ 推送配置文件到minion端 """
    if not check_configid(session['configid']):
        return redirect(url_for('.set_conf_query'))
    new_sls = CreateSLS(session['configid'])
    new_sls.push_config(istest=False)
    logger.info(u'推送配置文件到minion端')
    flash(u'推送配置文件到minion端')
    return redirect(url_for('.set_conf_query'))

@cfm.route('/_push_sls/', methods=['GET', 'POST'])
@login_required
def _push_sls():
    """ 推送配置文件到minion端 """
    logs = ''
    if request.method == 'POST' and session['configid'] is not None:
        new_sls = CreateSLS(session['configid'])
        logs = new_sls.push_config(istest=False)
        logger.info(u'推送配置文件到minion端')
    else:
        logger.error(u'推送配置文件到minion端失败，请检查.')
    return logs

