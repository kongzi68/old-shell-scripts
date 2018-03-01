# coding=utf-8
import smtplib
import ConfigParser
import logging
from email.mime.text import MIMEText
from email.header import Header

logger = logging.getLogger(__name__)

cf = ConfigParser.ConfigParser()
cf.read('config/cmdb.conf')
m_host = cf.get('email', 'm_host')
m_user = cf.get('email', 'm_user')
m_pass = cf.get('email', 'm_pass')
receivers = cf.get('email', 'receivers')

def sendEmail(content):
    """
    :param content:
    :return:
    """
    message = MIMEText(content, 'plain', 'utf-8')
    message['From'] = Header("monitor<{0}>".format(m_user), 'utf-8')
    subject = 'SALTSTACK PING CHECK FAILURE SERVER'
    message['Subject'] = Header(subject, 'utf-8')

    try:
        smtpObj = smtplib.SMTP(m_host)
        smtpObj.login(m_user, m_pass)
        for item in receivers.split(','):
            message['To'] = Header(item, 'utf-8')
            smtpObj.sendmail(m_user, [item], message.as_string())
    except Exception as error:
        logger.error(error)
        pass