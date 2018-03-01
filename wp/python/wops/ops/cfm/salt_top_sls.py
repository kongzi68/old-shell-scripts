#!/usr/bin/env python
#coding=utf-8
import ast
import glob
import os
import sys
import salt.utils.find
import zipfile


file_name = 'salt_MqUYFVXFZkQeZoEx9WRLrLYSs9igvsOmCuun1KmZ.txt'
salt_dir = '/srv/salt'


def find(path, *args, **kwargs):
    '''
    查找文件
    files = find('/srv/salt', type='f', name='*.zip')
    files = find('/srv/salt', type='f', name='ServerConfig.xml')
    files = find('/srv/salt', type='f', name='\w{16}.zip')
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

def unzip_file(filename, filedir):
    ''' 解压文件 '''
    filename = str(filename)
    filedir = str(filedir)
    if zipfile.is_zipfile(filename):
        try:
            fz = zipfile.ZipFile(filename,'r')
            for file in fz.namelist():
                fz.extract(file, filedir)
        except IOError:
            pass

def get_sls_map():
    ''' 创建字典类型的top_sls映射关系 '''
    ret = {}
    t_ret = {}
    files = find(salt_dir, type='f', name=file_name)
    for t_file in files:
        with open(t_file, 'rb') as f:
            content = f.read()
        t_dict = ast.literal_eval(content)
        for key, value in t_dict.items():
            t_ret.setdefault(key, []).append(value)
    for key, value in t_ret.items():
        t_value = []
        for item in value:
            t_value += item
        ret[key] = t_value
    return ret

def create_master_top_sls():
    ''' 返回符合salt特定格式的字典 '''
    ret = {'environment': 'base', 'classes': []}
    t_dict = get_sls_map()
    if sys.argv[1] in t_dict.keys():
        ret['classes'] = t_dict.get(sys.argv[1], [])
    return ret


#####################
if __name__ == '__main__':
    files = find(salt_dir, type='f', name='\w{16}.zip')
    for t_file in files:
        unzip_file(t_file, salt_dir)
        os.remove(t_file)
    ret = create_master_top_sls()
    print ret
