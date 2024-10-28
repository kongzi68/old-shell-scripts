#!/usr/bin/env python
#coding=utf-8

import ftplib
import glob
import os
import zipfile

# Import salt libs
import salt.utils
import salt.utils.find
import salt.utils.psutil_compat as psutil

import sys
reload(sys)
sys.setdefaultencoding('utf-8')

# dir_key = 'WS'
dir_key = 'WorldServer'
exclude_dir = ['test', 'bak', 'back', 'backup']

def ftp_get_file(update_file, ftpdir):
    '''
    FTP下载
    使用：salt 'win2008' updategs.ftp_get_file 'GameServer.zip' '20161130'
    '''
    ftpdir = str(ftpdir)
    update_file = str(update_file)
    ftp = ftplib.FTP()
    try:
        # ftp.connect('iamIPaddress', 21)
        # ftp.login('ftpuser', '123456')
        ftp.connect('iamIPaddress', 21)
        ftp.login('ftptest', r'123456')
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
              psutil.disk_partitions('False')]
    for item in disk_infos:
        if item['fstype'] == 'NTFS':
            result.append(item['mountpoint'])
    return result

def get_GS_path():
    '''
    获取有效的ServerConfig.xml配置文件路径
    '''
    result = []
    for item in disk_partitions():
        files = find(item, type='f', name='ServerConfig.xml')
        if files:
            for tfile in files:
                gsdir = tfile.split('\\')[1].lower()
                i = 0
                for tkey in exclude_dir:
                    if tkey in gsdir: i += 1
                if i > 0:
                    continue
                elif dir_key.lower() in gsdir:
                    result.append(tfile)
    return result

def upgrade(filename, ftpdir, doit=False):
    '''
    filename  更新包名称
    ftpdir  更新包在ftp中的目录名称
    doit  'True'表示更新，'False'表示测试
    测试：salt 'win2008' updategs.upgrade 'GameServer.zip' '20161130'
    更新：salt 'win2008' updategs.upgrade 'GameServer.zip' '20161130' doit=True
    报错处理：
        F:\GS1:False，状态为False有两种情况：
            1、测试的时候，会显示为False；
            2、压缩包内的文件解压到目标文件夹时莫有权限，一般是该文件被进程占用
    '''
    result = []
    filename = str(filename)
    ftpdir = str(ftpdir)
    ftp_status = ftp_get_file(filename, ftpdir)
    if ftp_status:
        for item in get_GS_path():
            t_item = item.split('\\')[0:2]
            gs_dir = '{0}\\{1}'.format(t_item[0], t_item[1])
            if doit:
                zip_status = file_zip(filename, gs_dir)
            else:
                zip_status = False
            if zip_status:
                result.append('{0}:True'.format(gs_dir))
            else:
                result.append('{0}:False'.format(gs_dir))
    else:
        return 'ftp error'
    os.remove(filename)
    return result


