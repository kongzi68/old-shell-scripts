# coding=utf-8
import hashlib
import os

def getID(*args):
    '''
    接收任意个字符串参数，生成16位md5，做ID值用
    key_value = getID(gs_info['GameServerIP2'], gs_info['sc_dir'])
    '''
    string = ''
    for arg in args:
        string = '{0}{1}'.format(string, arg)
    string = str(string).encode('utf-8')
    m = hashlib.md5()
    m.update(string)
    return m.hexdigest()[8:-8]

def getMD5(*args):
    '''
    接收任意个字符串参数，生成md5值
    key_value = getID(gs_info['GameServerIP2'], gs_info['sc_dir'])
    '''
    string = ''
    for arg in args:
        string = '{0}{1}'.format(string, arg)
    string = str(string).encode('utf-8')
    m = hashlib.md5()
    m.update(string)
    return m.hexdigest()


class Lock(object):

    def __init__(self):
        super(Lock, self).__init__()
        self.lockfile = 'log/lock_file.lc'

    def lock(self):
        if not os.path.isfile(self.lockfile):
            os.mknod(self.lockfile)

    def unlock(self):
        if os.path.isfile(self.lockfile):
            os.remove(self.lockfile)

    def islock(self):
        if os.path.isfile(self.lockfile):
            return True
        else:
            return False
