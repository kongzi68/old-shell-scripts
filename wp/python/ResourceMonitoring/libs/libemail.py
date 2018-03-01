# coding=utf-8
import ConfigParser
import logging
import json
import os
import requests
import smtplib
import time
from common import str_code
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from email.header import Header


logger = logging.getLogger(__name__)

staffinfofile = 'log/staffinfo.txt'

cf = ConfigParser.ConfigParser()
cf.read('config/config.conf')
m_host = cf.get('email', 'm_host')
m_user = cf.get('email', 'm_user')
m_pass = cf.get('email', 'm_pass')
all_receiver = cf.get('email', 'receivers')
all_cc_receiver = cf.get('email', 'cc_receivers')

def saveAllAddress(update=False):
    """
    :param update:
    :return:
    """
    url = 'http://119.29.68.229:8083/api_sms/StaffInfo.php'
    now_time = time.mktime(time.localtime(time.time()))

    if os.path.isfile(staffinfofile):
        file_time = os.path.getmtime(staffinfofile)
        interval = int(now_time - file_time)
    else:
        interval = 0

    # 当文件不存在时，或者是手动更新时，或者是更新时间大于等于一周时，将再次从api拉起最新通信录
    if (not os.path.isfile(staffinfofile)) or update or interval >= 604800:
        infos = requests.get(url)
        if infos.ok:
            with open(staffinfofile, 'wb') as f:
                f.write(str(infos.text))
            log_str = '组别、姓名、电话、地址已从API更新成功，并保存到：{0}'.format(staffinfofile)
            logger.info(log_str.decode('utf-8'))

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
    :param type:
    :return: [] 列表
    """
    ret = []
    name_list = commonSplit(names)
    with open(staffinfofile, 'rb') as f:
        t_info = f.read()

    for item in json.loads(t_info):
        name = item.get('name').encode('utf-8')
        en_name = item.get('en_name').encode('utf-8')
        if (name in name_list) or (en_name in name_list):
            # logger.info('{0},,,{1}'.format(name, name_list))
            if type == 'phone':
                ret.append(item.get('phone').strip())  # 去掉可能存在两边的空格
            elif type == 'email':
                ret.append(item.get('email').strip())

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
    message = MIMEText(content, 'plain', 'utf-8')
    message['From'] = Header("monitor<{0}>".format(m_user), 'utf-8')
    message['To'] = Header(','.join(receivers), 'utf-8')
    if cc_receivers:
        message['Cc'] = Header(','.join(cc_receivers), 'utf-8')
    message['Subject'] = Header(subject, 'utf-8')
    try:
        smtpObj = smtplib.SMTP(m_host)
        smtpObj.login(m_user, m_pass)
        # 采用循环这种方式，当某邮件地址有误时，其它人也能继续收到
        for receiver in (receivers + cc_receivers):
            smtpObj.sendmail(m_user, [receiver], message.as_string())
            log_str = '发送邮件给 {0} 成功.'.format(receiver)
            logger.info(log_str.decode('utf-8'))
        smtpObj.quit()
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
    message = MIMEMultipart('related')
    message['From'] = Header("monitor<{0}>".format(m_user), 'utf-8')
    message['To'] = Header(','.join(receivers), 'utf-8')
    if cc_receivers:
        message['Cc'] = Header(','.join(cc_receivers), 'utf-8')
    message['Subject'] = Header(subject, 'utf-8')
    message.attach(MIMEText(content, 'plain', 'utf-8'))

    # 构造附件
    annex_names = commonSplit(annexs)
    for annex_name in annex_names:
        if not os.path.isfile(annex_name):
            log_str = "附件：{0} 不存在，请检查路径是否正确".format(annex_name)
            logger.error(log_str.decode('utf-8'))
            continue
        try:
            att = MIMEApplication(open(annex_name, 'rb').read())
            annex_name = os.path.basename(annex_name)
            att.add_header('Content-Disposition', 'attachment', filename=annex_name)
            message.attach(att)
        except Exception as error:
            logger.error(error)
            return False
    try:
        smtpObj = smtplib.SMTP(m_host)
        smtpObj.login(m_user, m_pass)
        for receiver in (receivers + cc_receivers):
            smtpObj.sendmail(m_user, [receiver], message.as_string())
            log_str = '发送邮件给 {0} 成功.'.format(receiver)
            logger.info(log_str.decode('utf-8'))
        smtpObj.quit()
        # logger.info(str(message.as_string()))
    except smtplib.SMTPException as error:
        logger.error(error)
        pass

def sendEmail(subject, content, annexs=None):
    saveAllAddress(update=True)
    receivers = getAddress(all_receiver, 'email')
    cc_receivers = getAddress(all_cc_receiver, 'email')
    if annexs:
        sendEmailAnnex(receivers, cc_receivers, subject, content, annexs)
    else:
        sendEmailText(receivers, cc_receivers, subject, content)

