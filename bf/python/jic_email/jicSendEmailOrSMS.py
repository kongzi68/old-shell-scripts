#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
import argparse
import configparser
import logging
import oracledb
import os
import sys
import textwrap
import time

## 配置文件名
CONFIGNAME = '{0}/conf/config.conf'.format(os.getcwd())
def get_loglevel_from_config():
    ret = logging.INFO
    if os.path.isfile(CONFIGNAME):
        cf = configparser.ConfigParser()
        cf.read(CONFIGNAME)
        log_level = cf.get("log_level", "loglevel")
    else:
        log_level = 'info'
    if log_level == 'info':
        ret = logging.INFO
    elif log_level == 'error':
        ret = logging.ERROR
    elif log_level == 'warning':
        ret = logging.WARNING
    elif log_level == 'debug':
        ret = logging.DEBUG
    return ret

## 设置log输出
logger = logging.getLogger()
logger.setLevel(get_loglevel_from_config())
# fh = logging.FileHandler('/var/log/alarm.log')
ch = logging.StreamHandler()
formatter = logging.Formatter("%(asctime)s %(levelname)s %(module)s-%(lineno)d::%(message)s")
# fh.setFormatter(formatter)
ch.setFormatter(formatter)
# logger.addHandler(fh)
logger.addHandler(ch)


def common_split(strings):
    """
    :param strings: 用逗号分隔的字符串: "zhangsan,lisi,wangmazi "
    :return: 返回列表['zhangsan', 'lisi', 'wangmazi']
    """
    if strings.find(',') >= 0:
        ret = strings.split(',')
    else:
        ret = [strings]

    return ret


def oracle_connection():
    oracledb.init_oracle_client()
    cf = configparser.ConfigParser()
    cf.read(CONFIGNAME)
    ## get获取的字符串带引号，传给oracledb使用前需要用eval转换成python内部的字符串类型
    #+ 但是用docker集成的python又不需要，神奇
    # user = eval(cf.get("oracledb", "user"))
    # password = eval(cf.get("oracledb", "password"))
    # host = eval(cf.get("oracledb", "host"))
    # port = cf.getint("oracledb", "port")
    # service_name = eval(cf.get("oracledb", "service_name"))
    user = cf.get("oracledb", "user")
    password = cf.get("oracledb", "password")
    host = cf.get("oracledb", "host")
    port = cf.getint("oracledb", "port")
    service_name = cf.get("oracledb", "service_name")
    logger.debug("{0},{1},{2},{3},{4}".format(user, password, host, port, service_name))
    cp = oracledb.ConnectParams()
    cp.parse_connect_string("{0}:{1}/{2}".format(host, port, service_name))
    dsn = cp.get_connect_string()
    logger.debug(dsn)
    conn = oracledb.connect(user=user, password=password, dsn=dsn)
    return conn


def insert_to_TINFO_SEND_RCD(data):
    conn = oracle_connection()
    cursor = conn.cursor()
    # 获取id
    ret_id = cursor.callfunc('livebos.func_nextid', int, ['TINFO_SEND_RCD'])
    logger.debug(ret_id)
    sql = """INSERT INTO "TINFO_SEND_RCD" ("ID", "BATCH_ID", "SEND_CHNL", "SEND_TO", "SEND_FROM", "RCV_TP",
        "RCVR_TP", "RCVR_ID", "SPCL_FLG", "TX_HASH", "IDV_FLG", "TITLE", "TX", "ST", "RMK", "ATT", "INST_ID", "BUS_SC",
        "INFO_TP", "IMPT_DGRE", "SRC_ATTR", "WTHR_READ", "READ_TM", "SRC_APP", "BUS_NO", "CRT_DT", "CRT_TM",
        "PRE_SND_TM", "SEND_DT", "SEND_TM", "AUDITOR", "AUDIT_TM")
        VALUES (:id, '0', :send_chnl, :send_to, NULL, '1', '1', '1', NULL, NULL,
        NULL, :title, :send_tx, '0', NULL, NULL, '0', '0', '0', '0', NULL, '0', NULL, '1', '0', :crt_dt, :crt_tm,
        NULL, '0', NULL, NULL, NULL)"""
    logger.debug(sql)
    data['id'] = str(ret_id) # 把id组装到字典data
    cursor.execute(sql, data)
    conn.commit()
    cursor.execute("select * from TINFO_SEND_RCD where ID=:id", id=ret_id)
    rows = cursor.fetchall()
    for row in rows:
        logger.info(row)
    cursor.close()
    conn.close()


def send_email_or_sms(args):
    logger.debug(args)
    args_dict = vars(args)
    logger.debug(args_dict)
    if 'message' in args_dict.keys(): # 短信
        send_chnl = 8
        title = args.title
        send_tx = args.message
    elif 'content' in args_dict.keys(): # 邮件
        send_chnl = 2
        title = args.subject
        send_tx = args.content
    crt_dt = time.strftime("%Y%m%d", time.localtime())
    crt_tm = time.strftime("%H:%M:%S", time.localtime())
    receiver_list = common_split(args.receivers)
    logger.info('下面将把需要发送的消息，写入Oracle库。')
    for receiver in receiver_list:
        data = dict(send_chnl=send_chnl, send_to=receiver, title=title, send_tx=send_tx, crt_dt=crt_dt, crt_tm=crt_tm)
        logger.debug(data)
        insert_to_TINFO_SEND_RCD(data)
    logger.info('写入数据库完成。')


def check_config():
    """
    处理配置文件config.conf
    """
    err_tips = textwrap.dedent(
        """
        ## 配置数据库连接信息
        #+ service_name 是 SID 或者 服务名，ORACLE_SID=oracledb
        [oracledb]
        user = username
        password = password
        host = iamIPaddress
        port = 1522
        service_name = oracledb

        ## 配置日志级别
        #+ 可选值为：info、error、warning、debug
        [log_level]
        loglevel = info
        """)
    config_name = CONFIGNAME
    if os.path.isfile(config_name):
        logger.debug('配置文件已存在，请自行检查配置文件是否正确')
    else:
        logger.error('工具所在目录: {0} 下无配置文件: {1} '.format(os.getcwd(), config_name))
        logger.info('已经导入如下配置文件{0}模板，请在当前目录下修改配置内容：{1}'.format(config_name, err_tips))
        with open(config_name, 'w+') as f:
            f.write(err_tips)


def get_help():
    parser = argparse.ArgumentParser(
        prog=sys.argv[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent(
            """
            Send Email or SMS.
            ____________________________
            Help:
                %(prog)s -h,--help
                %(prog)s email -h
                %(prog)s sms -h

            Usage Examples:
                %(prog)s email -r 123@qq.com -s 每日数据更新失败 -c zjt测试环境，每日数据未更新成功告警
                %(prog)s email -r zhangsan@betack.com,123@qq.com -s 每日数据更新失败 -c zjt测试环境，每日数据未更新成功告警
                %(prog)s sms -r 15982363559 -m zjt测试环境，每日数据未更新成功告警
                %(prog)s sms -r 15982363559,16789001111 -m zjt测试环境，每日数据未更新成功告警
            """
        )
    )

    # 子命令
    subparsers = parser.add_subparsers(title='功能模块')

    # 邮件通知
    email_parser = subparsers.add_parser(
        'email',
        help='zjt邮件通知',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent(
            """
            发送邮件告警
            ----------------------------------------
            Usage:
               %(prog)s -h,--help
               %(prog)s -r zhangsan@qq.com -c zjt测试环境，每日数据未更新成功告警
               %(prog)s -r zhangsan@qq.com,lisi@163.com -s 每日数据更新失败 -c zjt测试环境，每日数据未更新成功告警
            """
        ))
    email_group = email_parser.add_argument_group('邮件通知')
    email_group.add_argument('-r', '--receivers',
                             required=True,
                             help='接收者的邮件地址，多个接收者用逗号分隔')
    email_group.add_argument('-s', '--subject',
                             default='邮件告警',
                             help='告警邮件主题，收到邮件时显示的标题，默认值：邮件告警')
    email_group.add_argument('-c', '--content',
                             required=True,
                             help='告警邮件内容')
    email_group.set_defaults(func=send_email_or_sms)

    # 短信通知
    sms_parser = subparsers.add_parser(
        'sms',
        help='zjt短信通知',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent(
            """
            发送短信告警
            ----------------------------------------
            Usage:
               %(prog)s -h,--help
               %(prog)s -r 15982360120 -m zjt测试环境，每日数据未更新成功告警
               %(prog)s -r 15982360120,16782560199 -t 每日数据更新失败 -m zjt测试环境，每日数据未更新成功告警
            """
        ))
    sms_group = sms_parser.add_argument_group('短信通知')
    sms_group.add_argument('-r', '--receivers',
                           required=True,
                           help='接收者的手机号码，多个接收者用逗号分隔')
    sms_group.add_argument('-t', '--title',
                           default='短信告警',
                           help='告警短信标题，默认值：短信告警')
    sms_group.add_argument('-m', '--message',
                           required=True,
                           help='告警短信内容')
    sms_group.set_defaults(func=send_email_or_sms)

    parser.add_argument('-v', '--version',
                        action='version',
                        help='显示版本信息',
                        version='%(prog)s 1.0 by colin, on 2023-05-05.')
    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)
    args = parser.parse_args()
    logger.debug(args)
    return args


def main():
    args = get_help()
    check_config()  # 检查配置文件是否存在
    args.func(args)


if __name__ == '__main__':
    main()

