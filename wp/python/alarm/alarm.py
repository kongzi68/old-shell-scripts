#!/usr/bin/env python
# -*- coding: UTF-8 -*-
import hashlib
import json
import logging
import os
import requests
import sys
import smtplib
import time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from email.header import Header


staffinfofile = '/tmp/staffinfo.txt'
m_host = 'smtp.exmail.qq.com'
m_user = 'mailuser'
m_pass = 'yourpassword'

# 设置log输出
logger = logging.getLogger()
logger.setLevel(logging.INFO)
fh = logging.FileHandler('/var/log/alarm.log')
ch = logging.StreamHandler()
formatter = logging.Formatter("%(asctime)s %(levelname)s %(module)s-%(lineno)d::%(message)s")
fh.setFormatter(formatter)
ch.setFormatter(formatter)
logger.addHandler(fh)
logger.addHandler(ch)


def saveAllAddress(update=False):
    """
    :param update:
    :return:
    """
    url = 'http://iamIPaddress:8080/api_sms/StaffInfo.php'   # 通讯录接口
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
            logger.info('组别、姓名、电话、地址已从API更新成功，并保存到：{0}'.format(staffinfofile))

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
            logger.info('发送邮件给 {0} 成功.'.format(receiver))
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
            logger.error("附件：{0} 不存在，请检查路径是否正确".format(annex_name))
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
            logger.info('发送邮件给 {0} 成功.'.format(receiver))
        smtpObj.quit()
        # logger.info(str(message.as_string()))
    except smtplib.SMTPException as error:
        logger.error(error)
        pass

def sendMessage(phones, content):
    """
    :param phone:
    :param content:
    :return:
    """
    url = 'http://iamIPaddress:8080/api_sms/Sms.php'      # 发送短信的API
    privateKey = '0ecylJDlLOCm1olAyXaEiNhdU4NFoTNzz8Z'
    for phone in phones:
        sign = hashlib.md5('{0}&{1}&{2}'.format(phone, content, privateKey))
        t_data = {'phone': phone, 'content': content, 'sign': sign.hexdigest()}
        req = requests.post(url, data=t_data)
        if req.ok:
            logger.info('Send message to {0} is successfully.'.format(phone))
        else:
            logger.info('Send message to {0} is failed, Please check.'.format(phone))

def getHelp():
    logger.error("Usage: {0} -h|--help, get help.".format(sys.argv[0]))
    sys.exit()

def printHelp():
    logger.info(" ")
    logger.info("特别说明：输入逗号分隔符的时候，请切换到英文输入法")
    logger.info(" ")
    logger.info("发送邮件：")
    logger.info("  邮件内容通过追加的方式:")
    logger.info("    不带附件: {0} -e receivers -c cc_receivers subject < 文件名(邮件内容保存在该文件中)".format(sys.argv[0]))
    logger.info("    带附件: {0} -e receivers -c cc_receivers subject annexs < 文件名".format(sys.argv[0]))
    logger.info("  邮件内容通过参数传递的方式:")
    logger.info("    不带附件: {0} -e receivers -c cc_receivers subject content".format(sys.argv[0]))
    logger.info("    带附件: {0} -e receivers -c cc_receivers subject content annexs".format(sys.argv[0]))
    logger.info("  发送邮件不抄送时:")
    logger.info("    不带附件: {0} -e receivers subject < 文件名".format(sys.argv[0]))
    logger.info("    不带附件: {0} -e receivers subject content".format(sys.argv[0]))
    logger.info("    带附件: {0} -e receivers subject annexs < 文件名".format(sys.argv[0]))
    logger.info("    带附件: {0} -e receivers subject content annexs".format(sys.argv[0]))
    logger.info("  参数详解：")
    logger.info("    -e 发送邮件")
    logger.info("    receivers 必须参数：接收者的姓名，姓名与姓名之间用逗号分隔，只有一个姓名时末尾不用加逗号")
    logger.info("                       接收者的姓名拼音全拼，用逗号分隔，只有一个时末尾不用加逗号")
    logger.info("    -c cc_receivers 非必须参数: 抄送者的姓名，用逗号分隔，只有一个时末尾不用加逗号")
    logger.info("                               抄送者的姓名拼音全拼，用逗号分隔，只有一个时末尾不用加逗号")
    logger.info("    subject 必须参数：邮件的主题，也就是收到邮件时显示的标题")
    logger.info("    content 邮件内容")
    logger.info("    annexs 邮件附件，附件名称与名称之间用逗号隔开，只有一个名称时末尾不用加逗号")
    logger.info(" ")
    logger.info("发送短信：")
    logger.info("  短信内容通过追加的方式:")
    logger.info("    {0} -m receivers < 文件名（邮件的内容保存在这个文件中）".format(sys.argv[0]))
    logger.info("  短信内容通过参数传递的方式:")
    logger.info("    {0} -m receivers content".format(sys.argv[0]))
    logger.info("  参数详解：")
    logger.info("    -m 发送短信")
    logger.info("    receivers 接收者的姓名或姓名拼音全拼，用逗号分隔，只有一个时末尾不用加逗号")
    logger.info("    content 短信内容")
    logger.info(" ")
    logger.info("手动更新邮件与电话等地址：")
    logger.info("    {0} -u".format(sys.argv[0]))
    logger.info("  参数详解：-u 表示从api获取最新的姓名、电话、邮件地址等")


if __name__ == '__main__':
    # 标准输入与追加方式
    if sys.stdin.isatty(): # 非追加方式
        if len(sys.argv) == 2:
            if sys.argv[1] in ['-h', '--help']:
                printHelp()
            elif sys.argv[1] == '-u':
                saveAllAddress(update=True)
            else:
                getHelp()
        elif len(sys.argv) >= 4 and len(sys.argv) <= 8:
            saveAllAddress()
            if sys.argv[1] == '-e':
                if sys.argv[3] == '-c': # 发邮件给抄送者
                    if len(sys.argv) == 7:
                        receivers = getAddress(sys.argv[2], 'email')
                        cc_receivers = getAddress(sys.argv[4], 'email')
                        subject = sys.argv[5]
                        content = sys.argv[6]
                        sendEmailText(receivers, cc_receivers, subject, content)
                    elif len(sys.argv) == 8:
                        receivers = getAddress(sys.argv[2], 'email')
                        cc_receivers = getAddress(sys.argv[4], 'email')
                        subject = sys.argv[5]
                        content = sys.argv[6]
                        annexs = sys.argv[7]
                        sendEmailAnnex(receivers, cc_receivers, subject, content, annexs)
                    else:
                        getHelp()
                else:
                    cc_receivers = []  # 发邮件不抄送时，指定cc_receivers为空列表
                    if len(sys.argv) == 5:
                        receivers = getAddress(sys.argv[2], 'email')
                        subject = sys.argv[3]
                        content = sys.argv[4]
                        sendEmailText(receivers, cc_receivers, subject, content)
                    elif len(sys.argv) == 6:
                        receivers = getAddress(sys.argv[2], 'email')
                        subject = sys.argv[3]
                        content = sys.argv[4]
                        annexs = sys.argv[5]
                        sendEmailAnnex(receivers, cc_receivers, subject, content, annexs)
                    else:
                        getHelp()
            elif sys.argv[1] == '-m':
                if len(sys.argv) == 4:
                    receivers= sys.argv[2]
                    content = sys.argv[3]
                    sendMessage(getAddress(receivers, 'phone'), content)
                else:
                    getHelp()
            else:
                getHelp()
        else:
            getHelp()
    else:
        # 通过追加方式传入邮件内容
        if len(sys.argv) == 2:
            if sys.argv[1] in ['-h', '--help']:
                printHelp()
            elif sys.argv[1] == '-u':
                saveAllAddress(update=True)
            else:
                getHelp()
        elif len(sys.argv) >= 3 and len(sys.argv) <= 7:
            saveAllAddress()
            if sys.argv[1] == '-e':
                if sys.argv[3] == '-c':
                    if len(sys.argv) == 6:
                        receivers = getAddress(sys.argv[2], 'email')
                        cc_receivers = getAddress(sys.argv[4], 'email')
                        subject = sys.argv[5]
                        content = sys.stdin.read()
                        sendEmailText(receivers, cc_receivers, subject, content)
                    elif len(sys.argv) == 7:
                        receivers = getAddress(sys.argv[2], 'email')
                        cc_receivers = getAddress(sys.argv[4], 'email')
                        subject = sys.argv[5]
                        annexs = sys.argv[6]
                        content = sys.stdin.read()
                        sendEmailAnnex(receivers, cc_receivers, subject, content, annexs)
                    else:
                        getHelp()
                else:
                    cc_receivers = []
                    if len(sys.argv) == 4:
                        receivers = getAddress(sys.argv[2], 'email')
                        subject = sys.argv[3]
                        content = sys.stdin.read()
                        sendEmailText(receivers, cc_receivers, subject, content)
                    elif len(sys.argv) == 5:
                        receivers = getAddress(sys.argv[2], 'email')
                        subject = sys.argv[3]
                        annexs = sys.argv[4]
                        content = sys.stdin.read()
                        sendEmailAnnex(receivers, cc_receivers, subject, content, annexs)
                    else:
                        getHelp()
            elif sys.argv[1] == '-m':
                if len(sys.argv) == 3:
                    receivers= sys.argv[2]
                    content = sys.stdin.read()
                    sendMessage(getAddress(receivers, 'phone'), content)
                else:
                    getHelp()
            else:
                getHelp()
        else:
            getHelp()
