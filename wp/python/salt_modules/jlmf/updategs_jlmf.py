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
import logging

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
exclude_dir = ['test', 'bak', 'back', 'backup','kd_ftpfile'] # 字母小写
# 泰国的系统是:"mm/dd/yyyy",国内的系统是:"yyyy/mm/dd"
date_type = '2050/01/01'

# 用于解压更新包的临时目录
temp_dir = 'D:\\temp_update_pkg'
if not os.path.exists(temp_dir): os.mkdir(temp_dir)

# 定义log日志格式
logger = logging.getLogger()
logger.setLevel(logging.INFO)
ch = logging.FileHandler('D:\\update.txt')
# 定义handler的输出格式formatter
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

def ftp_get_file(update_file, ftpdir):
    '''
    FTP下载
    使用：salt 'win2008' updategs.ftp_get_file 'GameServer.zip' '20161130'
    '''
    ftpdir = str(ftpdir)
    update_file = str(update_file)
    ftp = ftplib.FTP()
    try:
        ftp.connect('ftp.cdn.qcloud.com', 21)
        ftp.login('1251001030_1004015_kd', r'kd@20170418')
        ftp.cwd(ftpdir)
        ftp.retrbinary('RETR {0}'.format(update_file),
            open(update_file, 'wb').write)
        ftp.quit()
        return True
    except ftplib.all_errors:
        return False

def find(path, *args, **kwargs):
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

def file_zip(filename, filedir):
    '''
    解压zip压缩包到指定目录
    若目标目录有同名文件，且被进程占用，解压会报IOError错误
    就算有同名文件，若未被进程占用，是可以正确替换和更新的
    '''
    filename = str(filename)
    filedir = str(filedir)
    iszip = zipfile.is_zipfile(filename)
    if iszip:
        try:
            fz = zipfile.ZipFile(filename,'r')
            for file in fz.namelist():
                fz.extract(file, filedir)
            return True
        except IOError:
            return False
    else:
        return False

def disk_partitions():
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

def get_gs_path(t_file):
    '''
    获取有效的Kd.Service.exe配置文件路径
    '''
    result = []
    t_file = str(t_file)
    for item in disk_partitions():
        files = find(item, type='f', name=t_file)
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
                        if t_item.lower() in gsdir:
                            result.append(tfile)
                            logger.info('{0}'.format(tfile))

    return result

def make_hash(filename, algo='md5'):
    '''
        Returns an md5 hash of the data in the file.
        For use as an imported imported function
        algo keyword argument should be one of the following:
        * md5
        * sha1
        * sha224
        * sha256
        * sha384
        * sha512
    '''
    m = getattr(hashlib, algo)()
    try:
        path = os.path.abspath(filename)
        with open(path, 'rb') as fname:
            contents = fname.read()
            m.update(contents)
        return m.hexdigest()
    except IOError as err:
        #print('[Errno {0}]: {1}'.format(err.errno, err.strerror))
        raise err

def check_md5(gs_dir, update_pkg_name, temp_dir):
    '''
    若for循环期间未检测出失败的情况，for循环结束后就返回True
    '''
    t_temp_dir = temp_dir + '\\' + update_pkg_name[:-4]
    t_dir = gs_dir.split('\\')
    g_dir = '\\'.join(t_dir[0:2])   # 游戏目录公共部分

    for IamUsername, _, files in os.walk(temp_dir):
        n_files = [os.path.join(IamUsername, name) for name in files] # 需更新的文件列表

        # 对游戏目录部分进行特殊处理
        u_gsdir = IamUsername.replace(t_temp_dir, g_dir)   # 替换成游戏目录公共部分
        t_u_gsdir = u_gsdir.split('\\')
        if len(t_u_gsdir) >= 5 and  t_u_gsdir[3] == 'kd.app.game': # 游戏程序目录
            if t_u_gsdir[4] == 'gs-1000':   # 游戏程序
                u_gsdir = u_gsdir.replace('gs-1000', t_dir[4])
            elif t_u_gsdir[4] == 'gslog-1000':  # 游戏日志
                u_gsdir = u_gsdir.replace('1000', t_dir[4].split('-')[1])

        u_files = [os.path.join(u_gsdir, name) for name in files]
        for i, item in enumerate(u_files):
            if os.path.isfile(item):
                u_md5 = make_hash(item)
            else:
                return False
            n_md5 = make_hash(n_files[i])
            if n_md5 != u_md5: return False
            logger.info('{2}, n_md5: {0}, u_md5: {1}'.format(n_md5, u_md5, item))

    return True

def copy_files_to_gsdir(gs_dir, update_pkg_name, temp_dir):
    '''
    gs_dir：是游戏程序执行文件所在目录的全路径
        D:\kd\runtime\kd.app.game\gs-1000\    # 游戏目录
        D:\kd\runtime\kd.app.game\gs-1003\
    
    temp_dir: 是定义的全局变量，临时解压目录

    update_pkg_name: 游戏更新包名称，压缩文件包，带.zip后缀
        kdsvr.add.fjveriamIPaddress-201709070516.zip

    说明，更新包解压之后的目录
        D:\temp_update_pkg\kdsvr.add.fjveriamIPaddress-201709070516
        D:\temp_update_pkg\kdsvr.add.fjveriamIPaddress-201709070516\runtime\kd.app.GameServer
    '''
    t_temp_dir = temp_dir + '\\' + update_pkg_name[:-4]
    t_dir = gs_dir.split('\\')
    g_dir = '\\'.join(t_dir[0:2])   # 游戏目录公共部分

    try:
        for IamUsername, _, files in os.walk(temp_dir):
            # 需更新的文件列表
            n_files = [os.path.join(IamUsername, name) for name in files] 

            ## 对游戏目录部分进行特殊处理
            u_gsdir = IamUsername.replace(t_temp_dir, g_dir)   # 替换成游戏目录公共部分
            t_u_gsdir = u_gsdir.split('\\')
            if len(t_u_gsdir) >= 5 and  t_u_gsdir[3] == 'kd.app.game': # 游戏程序目录
                if t_u_gsdir[4] == 'gs-1000':   # 游戏程序
                    u_gsdir = u_gsdir.replace('gs-1000', t_dir[4])
                elif t_u_gsdir[4] == 'gslog-1000':  # 游戏日志
                    u_gsdir = u_gsdir.replace('1000', t_dir[4].split('-')[1])

            # 若需要更新的文件夹，目标目录不存在，就创建
            if not os.path.exists(u_gsdir):
                os.makedirs(u_gsdir)

            # 把当前目录下的文件复制到需被更新目录
            for item in n_files:
                shutil.copy2(item, u_gsdir)
    except Exception:
        return False
    else:
        return True


def upgrade(filename, ftpdir, doit=False):
    '''
    filename  更新包名称
    ftpdir  更新包在ftp中的目录名称
    doit  'True'表示更新，'False'表示测试
    游戏服：
        测试：salt -N GMServer updategs.upgrade 'GameServer.zip' '20161130'
        正式：salt -N GMServer updategs.upgrade 'GameServer.zip' '20161130' doit=True
    世界服：
        测试：salt -N WSServer updategs.upgrade 'WorldServer.zip' '20161130'
        正式：salt -N WSServer updategs.upgrade 'WorldServer.zip' '20161130' doit=True
    备注：游戏服与世界服在/etc/salt/master中一定要分组
    报错处理：
        F:\GS1:False，状态为False有以下几种情况：
            1、测试的时候，会显示为False；
            2、压缩包内的文件解压到目标文件夹时莫有权限，一般是该文件被进程占用
            3、更新文件失败或更新后游戏程序目录的文件与更新包文件md5不匹配
    '''
    result = []
    filename = str(filename)
    ftpdir = str(ftpdir)
    ftp_status = ftp_get_file(filename, ftpdir)
    if ftp_status:
        if file_zip(filename, temp_dir):
            logger.info('Unzip successfuly.')
            for item in get_gs_path('Kd.GameService.exe.config'):
                gs_dir = item.replace('Kd.GameService.exe.config', '')
                logger.info('{0}'.format(gs_dir))
                if doit:
                    if copy_files_to_gsdir(gs_dir, filename, temp_dir):
                        logger.info('update files to {0}'.format(gs_dir))
                        if check_md5(gs_dir, filename, temp_dir):
                            result.append('{0}: Update successfuly.'.format(gs_dir))
                            logger.info('check md5 successfuly.')
                        else:
                            result.append('{0}: Update failed.'.format(gs_dir))
                    else:
                        result.append('{0}: Update failed.'.format(gs_dir))
                else:
                    result.append('{0}: Test.'.format(gs_dir))
        else:
            result.append('Unzip update_pkg filed')
    else:
        result.append('Ftp error')

    os.remove(filename)
    shutil.rmtree(temp_dir)

    return result
