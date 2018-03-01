#coding=utf-8
import logging
from . import cmdb
from ..models import TServer, TConfig, TConfigDict, TGametype
from flask_login import login_required, fresh_login_required
from flask import render_template, flash, request, jsonify, redirect, url_for, session
from .forms import ConfigServerForm
from .. import db
from ..libs.common import getID


logger = logging.getLogger(__name__)



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
    ret.append((9999, 'ALL'))
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
    if game_id == 9999:
        return ret
    for obj_item in TServer.query.filter_by(game_id=game_id).all():
        envs = obj_item.env
        for env in envs.split(','):
            t_ret.add(env)
    for item in t_ret:
        ret.append((item, item))
    ret.append(('ALL', 'ALL'))
    return ret


@cmdb.route('/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def cat_servers():
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
    return render_template('cmdb/cat_servers.html',
                           model_name='.cat_servers',
                           form=form)


@cmdb.route('/set_gametype/', methods=['GET', 'POST'])
@login_required
@fresh_login_required
def set_gametype():
    pass
    return render_template('cmdb/set_gametype.html',
                           model_name='.set_gametype')


@cmdb.route('/api/_api_table_data_tserver/')
@login_required
def _api_table_data_tserver():
    salt_group = session['salt_group']
    gameid = session['gameid']
    logger.debug("GAMEID: {0};;SALT_GROUP: {1}".format(gameid, salt_group))
    logger.debug("GAMEID: {0};;SALT_GROUP: {1}".format(type(gameid), type(salt_group)))
    if salt_group and gameid:
        if int(gameid) == 9999:
            page_data = TServer.query.all()
        else:
            if salt_group == 'ALL':
                page_data = TServer.query.filter(TServer.game_id==gameid).all()
            else:
                page_data = TServer.query.filter(TServer.env.like('%{0}%'.format(salt_group)),
                                                 TServer.game_id==gameid).all()
    else:
        page_data = TServer.query.all()
    datas = jsonify([obj_item.to_json() for obj_item in page_data])
    return datas


@cmdb.route('/api/_api_table_data_tgametype/')
@login_required
def _api_table_data_tgametype():
    page_data = TGametype.query.all()
    datas = jsonify([obj_item.to_json() for obj_item in page_data])
    return datas


@cmdb.route('/_get_salt_group/')
@login_required
@fresh_login_required
def _get_salt_group():
    logger.debug(str(request.args))
    game_id = request.args.get('game_id', 'game_id', type=str)
    logger.debug(str(game_id))
    env = get_salt_group(game_id)
    return jsonify(env)

@cmdb.route('/_get_gameid/')
@login_required
@fresh_login_required
def _get_gameid():
    ret = get_gameid()
    # logger.debug(str(ret[:-1]))
    return jsonify(ret[:-1])


@cmdb.route('/api/_api_save_datas/', methods=['GET', 'POST'])
@login_required
def _api_save_datas():
    logger.debug(request.get_json())
    datas = request.get_json()
    t_datas = datas.get('datas')
    logger.debug(type(t_datas))
    logger.info(t_datas)
    server_id = t_datas.get('server_id')
    ip = t_datas.get('ip')
    saltid = t_datas.get('saltid')
    if server_id:
        # 更新修改的数据
        ret = TServer.query.filter_by(server_id=server_id).first()
        ret.game_id = t_datas.get('game_id')
        ret.hostname = t_datas.get('hostname')
        ret.ip = ip
        ret.netip = t_datas.get('netip')
        ret.os = t_datas.get('os')
        ret.cpu = t_datas.get('cpu')
        ret.mem = t_datas.get('mem')
        ret.disk = t_datas.get('disk')
        ret.status = t_datas.get('status')
        ret.env = t_datas.get('env')
        ret.saltid = saltid
        ret.uninstanceid = t_datas.get('uninstanceid')
        ret.price = t_datas.get('price')
        ret.cvmtype = t_datas.get('cvmtype')
        ret.bandwidth = t_datas.get('bandwidth')
    else:
        # 添加新数据
        server_id = getID(ip, saltid)
        data = TServer(
            game_id=t_datas.get('game_id'),
            hostname=t_datas.get('hostname'),
            ip=ip,
            netip=t_datas.get('netip'),
            os=t_datas.get('os'),
            cpu=t_datas.get('cpu'),
            mem=t_datas.get('mem'),
            disk=t_datas.get('disk'),
            status=t_datas.get('status'),
            env=t_datas.get('env'),
            saltid=saltid,
            uninstanceid=t_datas.get('uninstanceid'),
            price=t_datas.get('price'),
            cvmtype=t_datas.get('cvmtype'),
            bandwidth=t_datas.get('bandwidth'),
            server_id=server_id)
        db.session.add(data)
    db.session.commit()
    logger.info(u"保存SERVER_ID为 {0} 的服务器成功.".format(server_id))
    return jsonify({'ret': True})


@cmdb.route('/api/_api_save_gametype/', methods=['GET', 'POST'])
@login_required
def _api_save_gametype():
    logger.debug(request.get_json())
    datas = request.get_json()
    t_datas = datas.get('datas')
    logger.debug(type(t_datas))
    logger.info(t_datas)
    form_type = t_datas.get('form_type')
    game_id = t_datas.get('game_id')
    ret = TGametype.query.filter_by(game_id=game_id).first()
    logger.error(form_type)
    if form_type == 'add':
        if ret:
            flash(u"游戏ID冲突，请重新设置")
            return jsonify({'ret': False})
        else:
            # 添加新数据
            data = TGametype(
                game_id=t_datas.get('game_id'),
                game=t_datas.get('game'),
                type=t_datas.get('type'))
            db.session.add(data)
            flash(u"添加数据成功")
    elif form_type == 'mod':
        # 更新修改的数据
        ret.game_id = t_datas.get('game_id')
        ret.game = t_datas.get('game')
        ret.type = t_datas.get('type')
        flash(u"更新数据成功")
    db.session.commit()
    logger.info(u"保存GAME_ID为 {0} 的游戏成功.".format(game_id))
    return jsonify({'ret': True})


@cmdb.route('/api/_delete_datas/', methods=['GET', 'POST'])
@login_required
def _delete_datas():
    logger.debug(request.get_json())
    datas = request.get_json()
    server_ids = datas.get('datas')
    logger.debug(type(server_ids))
    logger.debug(server_ids)
    # 只可以删除status=0的
    for server_id in server_ids.split(','):
        del_status = TServer.query.filter_by(server_id=server_id, status=0).delete()
        if bool(del_status):
            logger.info(u"删除SERVER_ID为 {0} 的服务器成功.".format(server_id))
        else:
            logger.info(u"删除SERVER_ID为 {0} 的服务器失败...".format(server_id))
    db.session.commit()
    return jsonify({'ret': True})


@cmdb.route('/api/_delete_gametype/', methods=['GET', 'POST'])
@login_required
def _delete_gametype():
    logger.debug(request.get_json())
    datas = request.get_json()
    game_ids = datas.get('datas')
    logger.debug(type(game_ids))
    logger.debug(game_ids)
    for game_id in game_ids.split(','):
        del_status = TGametype.query.filter_by(game_id=game_id).delete()
        if bool(del_status):
            logger.info(u"删除GAME_ID为 {0} 的游戏成功.".format(game_id))
        else:
            logger.info(u"删除GAME_ID为 {0} 的游戏失败...".format(game_id))
    db.session.commit()
    return jsonify({'ret': True})