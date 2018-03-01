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

# 定义需要被更新的程序目录的关键词
# 比如泰国：游戏服的程序目录关键词为：GS
# 世界服的程序目录关键词为：WS
# 还比如：国内游戏服的程序目录关键词为：3JianHaoServer
# dir_key = ['GS', 'WS']
dir_key = ['kd']
exclude_dir = ['test', 'bak', 'back', 'backup', 'kd_ftpfile'] # 字母小写
# 泰国的系统是:"mm/dd/yyyy",国内的系统是:"yyyy/mm/dd"
date_type = '2050/01/01'

class StartGS(object):
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
        super(StartGS, self).__init__()
        self.date_type = date_type

    def class_main(self):

        # 获取GSM进程清单
        self.ps_list = self.get_gs_path('Kd.GameService.exe')
        time.sleep(2)
        # 获取到GSM清单之后，开始关闭进程
        #self.clean_process()
        # 禁用使用空密码的本地账户只允许进行控制台登录
        self.mod_gpedit(0)
        time.sleep(2)
        # 启动GSM
        ret = self.start_gs(self.ps_list)
        # 启用使用空密码的本地账户只允许进行控制台登录
        time.sleep(2)
        self.mod_gpedit(1)
        return ret

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

    def get_gs_process_status(self, ps_exe):
        '''判断进程是否启动'''
        ret = False
        for ps_item in psutil.process_iter():
            try:
                if ps_item.exe() == ps_exe:
                    ret = True
                    break
            except Exception:
                pass
        return ret


    def find(self, path, *args, **kwargs):
        '''
        查找文件
        函数的具体使用方法，用下面的命令获取帮助:
        salt 'win2008' sys.doc file.find
        '''
        if 'delete' in args:
            kwargs['delete'] = 'f'
        elif 'print' in args:
            kwargs['print'] = 'path'

        try:
            finder = salt.utils.find.Finder(kwargs)
        except ValueError as ex:
            return 'error: {0}'.format(ex)

        ret = [item for i in [finder.find(p) for p in
               glob.glob(os.path.expanduser(path))] for item in i]
        ret.sort()
        return ret

    def disk_partitions(self):
        '''
        返回结果为列表，类是：['/', '/data']
        '''
        result = []
        disk_infos = [dict(partition._asdict()) for partition in
                      spsutil.disk_partitions('False')]
        for item in disk_infos:
            if item['fstype'] == 'NTFS':
                result.append(item['mountpoint'])
        return result


    def get_gs_path(self, t_file):
        '''
        获取有效的Kd.GameService.exe.config配置文件路径
        '''
        result = []
        t_file = str(t_file)
        for item in self.disk_partitions():
            files = self.find(item, type='f', name=t_file)
            if files:
                for tfile in files:
                    gsdir = tfile.split('\\')[1].lower()
                    i = 0
                    for tkey in exclude_dir:
                        if tkey in gsdir: i += 1
                    if i > 0:
                        continue
                    else:
                        for t_item in dir_key:
                            if t_item.lower() in gsdir: result.append(tfile)
            else:
                result.append('Find config failed.')

        return result

    def mod_gpedit(self, values):
        '''
        values：值为1时，表示启用使用空密码的本地账户只允许进行控制台登录
                值为0时，表示禁用，禁用之后计划任务才能免密码运行
        '''
        gp_str = """
        [Version]
        signature="$CHICAGO$"
        [Registry Values]
        MACHINE\System\CurrentControlSet\Control\Lsa\LimitBlankPasswordUse=4,{0}
        """.format(values)
        with open('gp.inf', 'wb') as gp:
            gp.write(gp_str)
            gp.flush
        os.system("secedit /configure /db gp.sdb /cfg gp.inf /quiet")
        os.system("del gp.sdb gp.inf")

    def create_restart_bat(self, bat_name, gs_dir):
        '''创建restart.bat'''
        bat_txt = """
                @echo off
                cd /d {0}
                start {0}\Kd.GameService.exe
                exit
                """.format(gs_dir)
        with open(bat_name, 'wb') as file:
            file.write(bat_txt)
            file.flush

    def start_gs(self, ps_list):
        '''启动成独立的窗口运行'''
        bat_name = 'restart.bat'
        ret = []
        for item in ps_list:
            t_item = item.split('\\')[0:5]
            gs_dir = '{0}\\{1}\\{2}\\{3}\\{4}'.format(t_item[0], t_item[1],t_item[2],t_item[3],t_item[4])
            if os.path.exists(gs_dir):
                os.chdir(gs_dir)
                if os.path.exists(item):
                    try:
                        self.create_restart_bat(bat_name, gs_dir)
                        schtask = """SCHTASKS /create /IT /RU {0} /tn saltsch /tr {1}\{2} /SC ONCE /SD {3} /ST 00:00 /F """.format('administrator', gs_dir, bat_name, self.date_type)
                        os.system(schtask)
                        os.system("SCHTASKS /run /tn saltsch")
                        time.sleep(1)  # 留一秒给GSM启动
                        os.system("SCHTASKS /delete /tn saltsch /F")
                        os.system("del {0}".format(bat_name))
                        time.sleep(1)  # 间隔一秒才检查状态，防闪退检查失败
                        if self.get_gs_process_status(item):
                            ps_status = '{0}: restart success.'.format(item)
                        else:
                            ps_status = '{0}: restart failed!!!'.format(item)
                        ret.append(ps_status)
                    except Exception as e:
                        ret.append('{0}: {1}'.format(item, e))

        return ret


def gs_start():
    '''
    功能：重启GameServerMannage.exe
    使用：
        游戏服：salt -N GMServer updategs.restart_gsm
        世界服：salt -N WSServer updategs.restart_gsm
        备注：游戏服与世界服在/etc/salt/master中一定要分组
    特别说明：
        只对拉起的GSM有效。
        只会重启报错的进程与未报错的进程，也就是能从进程中获取到的管理工具进程
    '''
    start = StartGS()
    return start.class_main()
