#!/usr/bin/env python
#-*- coding: utf-8 -*-

"""
编辑:Fiber
版本:1.0
日期:2015-05-12
说明:
    1、该程序运行在中心节点，用于检测与中心节点相关联的IP是否畅通
    2、判断依据:调用ping命令，检查lost packet，如果100%则说明网络不通
    3、如果发现某一个IP不通，则调用WriteLog()函数进行写日志，日志默认路径：/root/NetCheck.log
    4、如果不通，则发送邮件告警。

"""

import os,sys,re
import subprocess

import logging

import fnmatch,time,smtplib,datetime
from email.header import Header
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


class CheckNet:
        def __init__(self,ip):
                        self.ip = ip
                        self.status = ""

        def NetCheck(self):
            try:
                p = subprocess.Popen(["ping -c 4 -w 4 "+ self.ip],stdout=subprocess.PIPE,stderr=subprocess.PIPE,shell=True)
                out=p.stdout.read()
                #err=p.stderr.read()
                regex=re.compile('100% packet loss')
                #print out
                #print regex
                #print err
                if len(regex.findall(out)) == 0:
                    #print ip + ': host up'
                    self.status = 'UP'
                    #self.WriteLog(self.ip+"  "+self.status)
                    return self.status
                else:
                #   print ip + ': host down'
                    self.status = 'DOWN'
                    self.WriteLog(self.ip+"  "+self.status)
                    return self.status
            except:
                #print 'NetCheck work error!'
                self.status = 'ERR'
                self.WriteLog(self.ip+"  "+self.status)
                return self.status

        def WriteLog(self,message):
            logger=logging.getLogger()
            log_time = time.strftime('%Y-%m-%d %H:%M:%S',time.localtime(time.time()))
            #filename = time.strftime('%Y-%m-%d',time.localtime(time.time()))  
            handler=logging.FileHandler("/root/NetCheck.log")

            logger.addHandler(handler)
            logger.setLevel(logging.NOTSET)
            logger.info(log_time+"\t"+message)

def SendMail(m_title,m_content):
        #发送邮件


        #附件
        #filename=sys.argv[1]
        #path='e://MyNotes//'+filename
        #path=sys.argv[1]

        server='mail.rockp.cn:465'#597 ssl 465
        user='user@rockp.cn'
        password='thisispassword'


        #att = MIMEText(open(path, 'rb').read(), 'base64', 'gb2312')
        #att["Content-Type"] = 'application/octet-stream'
        #att["Content-Disposition"] = 'attachment; filename='+filename

        att = MIMEText(m_content,_subtype='plain',_charset='utf-8')
        msg = MIMEMultipart()
        msg.attach(att)
        #
        #msg['to'] ='fiber@rockp.cn'
        mail_to = ["yunwei@rockp.cn","15200000000@139.com"]
        mail_from = 'user@rockp.cn'
        msg['subject'] = Header(m_title,'utf-8')

        #
        server = smtplib.SMTP_SSL(server)
        try:
            #server.set_debuglevel(1)
            server.login(user,password)
            server.sendmail(mail_from, mail_to, msg.as_string())
        except:
            #print ('send failed')
            send_status = 'failed'
            return send_status
            # self.WriteLog("邮件发送失败,title:"+self.m_title+",  content:"+self.m_content)
            #os.system('pause')
        else:
            #print ('send ok')
            send_status = 'OK'
            return send_status
            #  os.system('pause')
        finally:
            server.quit

        server.close

if __name__ == '__main__':

        station = "交运平度站"
        #logFile = '/root/NetCheck.log'
        """
        ip_addr = {
                        'jnac':'172.31.30.253',
                        }
        """
        vpn_addr = [
                        "20.0.255.254",
                   ]


        for ip in vpn_addr:
                p = CheckNet(ip)
                p_status = p.NetCheck()
                if p_status == 'DOWN' or p_status == 'ERR':
                        m_title = station +"到"+ip+"有VPN故障"
                        m_content = station + "到"+ip+"有VPN故障，请及时检查!"

                        s = SendMail(m_title,m_content)
                        #print send_status
                        if s == 'failed':
                                s = CheckNet("127.0.0.1")
                                s.WriteLog("邮件发送失败")
