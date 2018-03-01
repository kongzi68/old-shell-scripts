#!/usr/bin/env python
#coding=utf-8
# by colin on 2016-11-25
# revision on 2017-09-12

import ftplib
import glob
import os
import hashlib
import shutil
import time
import zipfile
import psutil
import win32api
import win32gui
import win32con

# Import salt libs
import salt.utils
import salt.utils.find
import salt.utils.psutil_compat as spsutil

import sys
reload(sys)
sys.setdefaultencoding('utf-8')


class StopGS(object):
    '''
    重启"GameServerMannage.exe"，以下简称GSM
    说明：
        GSM在停服之后，经常会报错，因不懂C#，没法优化这个GSM程序，现通过python脚本方式
        实现每次停服更新游戏时，关闭现有的GSM，并再次启动这些GSM。
    特别说明：
        只对拉起的GSM有效。
        只会重启报错的进程与未报错的进程，也就是能从进程中获取到的管理工具进程
        SO，第一次运行的时候，必须要手动拉起GSM
    '''
    def __init__(self):
        super(StopGS, self).__init__()
        self.date_type = date_type

    def stop_gs(self):
        #获取GSM进程清单
        self.ps_list = self.get_gs_process_info('Kd.GameService.exe')
        time.sleep(2)
        # 获取到GSM清单之后，开始关闭进程
        self.clean_process()
        # 禁用使用空密码的本地账户只允许进行控制台登录
        time.sleep(2)

    def send_string(self, hwnd, msg):
        '''发送字符串,只能发送英文字符串'''
        for item in msg:
            win32api.SendMessage(hwnd, win32con.WM_CHAR, ord(item), 0)
        # 发送回车键
        win32api.PostMessage(hwnd, win32con.WM_KEYDOWN, win32con.VK_RETURN, 0)
        win32api.PostMessage(hwnd, win32con.WM_KEYUP, win32con.VK_RETURN, 0)

    def kill_process(self, ps_name):
        for ps_item in psutil.process_iter():
            if ps_item.name() == ps_name:
                ps_item.kill()

    def clean_process(self):
        '''关闭进程'''
        # 清理GSM报错产生的WerFault.exe进程
        self.kill_process('WerFault.exe')

        # 发送@exit命令，关闭GS
        for ps_item in psutil.process_iter():
            try:
                if ps_item.name() == 'Kd.GameService.exe':
                    gsm_hwnd = win32gui.FindWindow(None, ps_item.exe())
                    self.send_string(gsm_hwnd, '@exit')
                    ps_item.kill() # 关闭正常退出GS后的GSM
            except Exception:
                pass

        # GSM报错退出后，未关闭的GS，将被强制结束进程
        self.kill_process('kd.GameService.exe')

    def get_gs_process_info(self, ps_name):
        '''
        获取指定进程的路径清单
        返回的结果为嵌套列表：[[],[]]
        '''
        ret = []
        for ps_item in psutil.process_iter():
            try:
                if ps_item.name() == ps_name:
                    t_ret = [ps_item.exe(), ps_item.username()]
                    ret.append(t_ret)
            except Exception:
                pass
        return ret


def gs_stop():
    stop = StopGS()
    return stop.stop_gs()
