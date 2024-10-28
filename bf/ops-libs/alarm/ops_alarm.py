#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
import argparse
import hashlib
import json
import logging
import os
import requests
import sys
import smtplib
import time
import textwrap
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from email.header import Header

staffinfofile = '/tmp/staffinfo.txt'
## 配置邮件发送
m_host = 'smtp.mxhichina.com'
m_port = 465
m_user = 'senderproduction@betack.com'
m_pass = 'Iampassword'
"""
如果设置的端口为 465，表示是加密发送邮件，is_ssl=True
若是非加密端口，需要设置为 is_ssl=False
云服务器上，25端口一般被禁用，执行如下代码，表现为没任何反应，给夯住了。
smtpObj = smtplib.SMTP('smtp.mxhichina.com', 25) 
最终会触发异常：TimeoutError: [Errno 110] Connection timed out
因此，推荐使用加密发送邮件
"""
is_ssl = True
timeout_sec = 60

# 设置log输出
logger = logging.getLogger()
logger.setLevel(logging.INFO)
# fh = logging.FileHandler('/var/log/alarm.log')
ch = logging.StreamHandler()
formatter = logging.Formatter("%(asctime)s %(levelname)s %(module)s-%(lineno)d::%(message)s")
# fh.setFormatter(formatter)
ch.setFormatter(formatter)
# logger.addHandler(fh)
logger.addHandler(ch)


API_URL = 'http://iamIPaddress:5000'
BASIC_SECRET = 'iamsecrets=='
# API_URL = 'http://iamIPaddress:8080'
# BASIC_SECRET = 'iamsecrets'
# 获取api的token
def get_token():
    """
    "Authorization": "Basic iamsecrets"
    是通过postman，或者浏览器，输入URL，填入用户名与密码请求成功后，在"Request Headers"里面找到的
    :return:
    """
    url = '{0}/api/v1.1/token/'.format(API_URL)
    header = {"Content-Type": "application/json", "Authorization": "Basic " + BASIC_SECRET}
    html = requests.get(url, headers=header)
    print(html)
    token = html.json()['token']
    logger.info(token)
    return token

def saveAllAddress(update=False):
    """
    :param update:
    :return:
    """
    url = '{0}/api/v1.1/contact_list'.format(API_URL)
    now_time = time.mktime(time.localtime(time.time()))

    if os.path.isfile(staffinfofile):
        file_time = os.path.getmtime(staffinfofile)
        interval = int(now_time - file_time)
    else:
        interval = 0
    # 当文件不存在时，或者是手动更新时，或者是更新时间大于等于一周时，将再次从api拉起最新通信录
    if (not os.path.isfile(staffinfofile)) or update or interval >= 604800:
        try:
            infos = requests.get(url, headers={"Authorization": "Bearer " + get_token()})
            if infos.ok:
                logger.info(type(infos.text))
                with open(staffinfofile, 'w') as f:
                    f.write(str(infos.text))
                logger.info('组别、姓名、电话、地址已从API更新成功，并保存到：{0}'.format(staffinfofile))
            else:
                logger.error('从API获取通讯地址失败')
        except requests.exceptions.ConnectionError as error:
            logger.error(error)

def commonSplit(strings):
    """
    :param strings: 用逗号分隔的字符串: "zhangsan,lisi,wangmazi "
    :return: 返回列表['zhangsan', 'lisi', 'wangmazi']
    """
    if strings.find(',') >= 0:
        ret = strings.split(',')
    else:
        ret = [strings]

    return ret

def getAddress(names, type):
    """
    :param names: 字符串，传的可能是用逗号分隔的中文姓名，也可能是用逗号分隔的姓名全拼
    :param type: phone | email
    :return: [] 列表
    """
    ret = []
    name_list = commonSplit(names)
    with open(staffinfofile, 'rb') as f:
        t_info = f.read()

    for item in json.loads(t_info):
        name = item.get('name')
        en_name = item.get('en_name')
        if (name in name_list) or (en_name in name_list):
            logger.debug('{0},,,{1}'.format(name, name_list))
            if type == 'phone':
                ret.append(item.get('phone'))
            elif type == 'email':
                logger.debug(item.get('email'))
                # 一个人可能有多个邮件接收地址，需要切割成单个地址
                for email in commonSplit(item.get('email')):
                    ret.append(email.strip())

    return ret

def sendEmailText(receivers, cc_receivers, subject, content):
    """
    发送text邮件
    :param receivers: 邮件接收者
    :param cc_receivers: 抄送邮件接收者
    :param subject: 邮件标题
    :param content: 邮件内容
    :return:
    """
    msg = MIMEText(content)
    # msg = MIMEText(content, 'plain', 'utf-8')
    msg['From'] = Header(m_user, 'utf-8')
    # msg['To'] = Header(', '.join(receivers), 'utf-8')
    # if cc_receivers:
    #     msg['Cc'] = Header(', '.join(cc_receivers), 'utf-8')
    msg['Subject'] = Header(subject, 'utf-8')
    try:
        ## 采用循环这种方式，当某邮件地址有误时，其它人也能继续收到
        for receiver in (receivers + cc_receivers):
            msg['To'] = Header(receiver, 'utf-8')
            if is_ssl:
                smtpObj = smtplib.SMTP_SSL(m_host, m_port, timeout=timeout_sec)
            else:
                smtpObj = smtplib.SMTP(m_host, m_port, timeout=timeout_sec)
            smtpObj.set_debuglevel(False)
            smtpObj.login(m_user, m_pass)
            logger.info(receiver)
            t_receiver = []
            t_receiver.append(receiver)
            smtpObj.sendmail(m_user, t_receiver, msg.as_string())
            smtpObj.quit()
            logger.info('发送邮件给 {0} 成功.'.format(receiver))
            # 避免登录邮件服务器频繁，发送速度太快
            time.sleep(2)
        logger.debug(str(msg.as_string()))

        ## 经验证，所有邮件接收者合并成一个列表，如果其中一个接收者邮箱是错误的
        #+ 那整封邮件会被退信，其它正常邮箱的将无法接收到邮件
        """
        if is_ssl:
            smtpObj = smtplib.SMTP_SSL(m_host, m_port, timeout=timeout_sec)
        else:
            smtpObj = smtplib.SMTP(m_host, m_port, timeout=timeout_sec)
        t_receivers = receivers + cc_receivers  # t_receivers 数据类型原本就是list
        smtpObj.login(m_user, m_pass)
        logger.info(t_receivers)
        #+ 但是这里有点奇怪，必须要用list转一次t_receivers后，才能成功接收到邮件
        smtpObj.sendmail(m_user, list(t_receivers), msg.as_string())
        logger.info('发送邮件给 {0} 成功.'.format(t_receivers))
        smtpObj.quit()
        logger.debug(str(msg.as_string()))
        """
    except smtplib.SMTPException as error:
        logger.error(error)
        pass

def sendEmailAnnex(receivers, cc_receivers, subject, content, annexs):
    """
    发送带附件的邮件
    :param receivers: 邮件接收者，列表
    :param cc_receivers: 抄送邮件接收者
    :param subject: 邮件标题，字符串
    :param content: 邮件内容，字符串
    :param annexs: 附件名称，多个附件之间用逗号分隔，字符串
    :return:
    """
    msg = MIMEMultipart('related')
    msg['From'] = Header(m_user, 'utf-8')
    msg['To'] = Header(','.join(receivers), 'utf-8')
    if cc_receivers:
        msg['Cc'] = Header(','.join(cc_receivers), 'utf-8')
    msg['Subject'] = Header(subject, 'utf-8')
    msg.attach(MIMEText(content, 'plain', 'utf-8'))

    # 构造附件
    annex_names = commonSplit(annexs)
    for annex_name in annex_names:
        if not os.path.isfile(annex_name):
            logger.error("附件：{0} 不存在，请检查路径是否正确".format(annex_name))
            continue
        try:
            att = MIMEApplication(open(annex_name, 'rb').read())
            annex_name = os.path.basename(annex_name)
            att.add_header('Content-Disposition', 'attachment', filename=annex_name)
            msg.attach(att)
        except Exception as error:
            logger.error(error)
            return False
    try:
        if is_ssl:
            smtpObj = smtplib.SMTP_SSL(m_host, m_port, timeout=timeout_sec)
        else:
            smtpObj = smtplib.SMTP(m_host, m_port, timeout=timeout_sec)
        smtpObj.login(m_user, m_pass)
        for receiver in (receivers + cc_receivers):
            t_receiver = []
            t_receiver.append(receiver)
            smtpObj.sendmail(m_user, t_receiver, msg.as_string())
            logger.info('发送邮件给 {0} 成功.'.format(receiver))
        smtpObj.quit()
        # logger.info(str(msg.as_string()))
    except smtplib.SMTPException as error:
        logger.error(error)
        pass

def sendMessage(args):
    """ 发送短信，需要调用短信发送接口才能用
    :param phone:
    :param message:
    :return:
    """
    url = 'http://iamIPaddress/api_sms/Sms.php'
    privateKey = '0ecylJDlLOm1olA1yXEihdU4NFoTNzz8Z'
    logger.info('发送短信')
    message = args.message
    phones = getAddress(args.receivers, 'phone')
    for phone in phones:
        sign = hashlib.md5('{0}&{1}&{2}'.format(phone, message, privateKey))
        t_data = {'phone': phone, 'content': message, 'sign': sign.hexdigest()}
        try:
            req = requests.post(url, data=t_data)
            if req.ok:
                logger.info('Send message to {0} is successfully.'.format(phone))
            else:
                logger.info('Send message to {0} is failed, Please check.'.format(phone))
        except requests.exceptions.ConnectionError as error:
            logger.error(error)

def callPhone(args):
    """ 打电话通知
    :param phone:
    :param content: 语音播报的内容，不能超过8个字符，一个中文算一个字符，比如：wind磁盘告警
    :return:
    """
    logger.info('电话通知')
    url = '{0}/api/v1.1/call_phone'.format(API_URL)
    header = {"Authorization": "Bearer " + get_token()}
    phones = getAddress(args.receivers, 'phone')
    for phone in phones:
        data = json.dumps({"callee_nbr": phone, "send_txt": args.voice_string})
        try:
            r = requests.post(url, json=data, headers=header)
            req = json.loads(r.text)
            req_code = req.get('status', 400)
            if req_code == 200:
                logger.info('拨打电话给 {0} 成功。'.format(phone))
            else:
                logger.error(req.get('msg'))
                logger.error('拨打电话给 {0} 失败！！！'.format(phone))
        except requests.exceptions.ConnectionError as error:
            logger.error(error)

def main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent("""\
        Send sms or Email.
        ____________________________
        Help:
            python {0} email -h
            python {0} sms --help
            python {0} call -h
        Usage Examples:
            python {0} email zhangsan,lisi 
            python {0} email zhangsan,lisi -cc wangmazi 
            python {0} email -r colin -s 'this is test' < email.txt
        """.format(sys.argv[0]))
    )

    # 子命令
    subparsers = parser.add_subparsers(
        title='功能模块',
        description='发送邮件，或发送短信'
    )

    # 发送邮件
    email_parser = subparsers.add_parser('email', help='发送邮件')
    email_group = email_parser.add_argument_group('发送邮件')
    email_group.add_argument(
        '-r', '--receivers',
        required=True,
        help='接收者的姓名或姓名拼音全拼，用逗号分隔，只有一个时末尾不用加逗号'
    )
    email_group.add_argument(
        '-cc', '--cc_receivers',
        help='抄送者的姓名或姓名拼音全拼，用逗号分隔，只有一个时末尾不用加逗号'
    )
    email_group.add_argument(
        '-s', '--subject',
        required=True,
        help='邮件的主题，收到邮件时显示的标题'
    )
    email_group.add_argument(
        '-c', '--content',
        help='邮件内容'
    )
    email_group.add_argument(
        '-a', '--annexs',
        help='邮件附件，附件名称与名称之间用逗号隔开，只有一个名称时末尾不用加逗号'
    )

    # 发送短信
    sms_parser = subparsers.add_parser('sms', help='发送短信')
    sms_group = sms_parser.add_argument_group('发送邮件')
    sms_group.add_argument(
        '-r', '--receivers',
        required=True,
        help='接收者的姓名或姓名拼音全拼，用逗号分隔，只有一个时末尾不用加逗号'
    )
    sms_group.add_argument(
        '-m', '--message',
        help='短信内容'
    )
    sms_group.set_defaults(func=sendMessage)

    # 拨打电话通知
    call_parser = subparsers.add_parser('call', help='电话通知')
    call_group = call_parser.add_argument_group('拨打电话')
    call_group.add_argument(
        '-r', '--receivers',
        required=True,
        help='接收者的姓名或姓名拼音全拼，用逗号分隔，只有一个时末尾不用加逗号'
    )
    call_group.add_argument(
        '-str', '--voice_string',
        help='电话通知的语音内容，不能超过8个字，比如：wind消息告警、国泰安客户端故障'
    )
    call_group.set_defaults(func=callPhone)

    # 手动更新邮件与电话等地址
    parser.add_argument('-u', '--update',
                        action='store_true',
                        help='从api获取最新的姓名、电话、邮件地址等')
    parser.add_argument('-v', '--version',
                        action='version',
                        help='显示版本信息',
                        version='%(prog)s 1.0 by colin, on 2022-06-10.')
    args = parser.parse_args()
    
    return args

if __name__ == '__main__':
    # 初始时，判断文件是否存在，不存在就更新
    if not os.path.isfile(staffinfofile):
        saveAllAddress(update=True)
    args = main()
    param_args = vars(args)
    if param_args.get('update'):
        # 手动更新通讯录
        saveAllAddress(update=True)
        sys.exit()
    else:
        logger.debug(sys.argv)
        if len(sys.argv)==1:
            sys.exit()
        # 通过判断发邮件的必须参数"subject"是否存在，来确定是发邮件还是短信
        # {'update': False, 'receivers': 'kxl', 'cc_receivers': 'zhangsan', 'subject': 'This is title', 'content': None, 'annexs': 'readme'}
        logger.info(param_args)
        # 符合条件自动更新通讯录
        saveAllAddress()
        if 'subject' in param_args.keys():
            receivers = getAddress(param_args.get('receivers'), 'email')
            if param_args.get('cc_receivers'):
                cc_receivers = getAddress(param_args.get('cc_receivers'), 'email')
            else:
                cc_receivers = []
            subject = param_args.get('subject')
            # 标准输入与追加方式输入发送内容
            if sys.stdin.isatty():
                logger.debug('a')
                content = param_args.get('content')
            else:
                logger.debug('b')
                content = sys.stdin.read()
                logger.debug(content)
            annexs = param_args.get('annexs')
            if annexs:
                logger.info('发送带附件的邮件')
                sendEmailAnnex(receivers, cc_receivers, subject, content, annexs)
            else:
                logger.info('发送邮件')
                sendEmailText(receivers, cc_receivers, subject, content)
        else:
            # {'update': False, 'receivers': 'zhangsan', 'message': '这是短信内容'}
            # {'update': False, 'receivers': 'zhangsan', 'telephone': '国泰安客户端故障'}
            args.func(args)

