# coding=utf-8
import hashlib
import os
from Crypto.Cipher import AES
from binascii import b2a_hex, a2b_hex


def getID(*args):
    '''
    接收任意个字符串参数，生成16位md5，做ID值用
    key_value = getID(gs_info['GameServerIP2'], gs_info['sc_dir'])
    '''
    string = ''
    for arg in args:
        arg = str_code(arg)
        string = '{0}{1}'.format(string, arg)
    # string = str(string).decode('utf-8')
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
        arg = str_code(arg)
        string = '{0}{1}'.format(string, arg)
    # string = str(string).decode('utf-8')
    m = hashlib.md5()
    m.update(string)
    return m.hexdigest()


def str_code(strings):
    if isinstance(strings, str):
        value = strings.decode('utf-8')
    elif  isinstance(strings, unicode):
        value = strings.encode('utf-8')
    else:
        value = strings
    return value


class Lock(object):
    """
    运行锁
    """
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


def rename_file(path, old_filename, new_filename):
    """
    文件在path目录下重命名
    :param path:
    :param old_filename:
    :param new_filename:
    :return:
    """
    old_file = os.path.join(path, old_filename)
    new_file = os.path.join(path, new_filename)
    if os.path.isfile(old_file):
        os.rename(old_file, new_file)


class Prpcrypt(object):
    """
    加密与解密
    key, 长度必须为16、24、32？
    """
    def __init__(self):
        super(Prpcrypt, self).__init__()
        self.key = "d7UfF7z_iP96dVkX"
        self.mode = AES.MODE_CBC

    #加密函数，如果text不是16的倍数【加密文本text必须为16的倍数！】，那就补足为16的倍数
    def encrypt(self, text):
        cryptor = AES.new(self.key, self.mode, self.key)
        #这里密钥key 长度必须为16（AES-128）、24（AES-192）、或32（AES-256）Bytes 长度.目前AES-128足够用
        length = 16
        count = len(text)
        add = length - (count % length)
        text = text + ('\0' * add)
        self.ciphertext = cryptor.encrypt(text)
        #因为AES加密时候得到的字符串不一定是ascii字符集的，输出到终端或者保存时候可能存在问题
        #所以这里统一把加密后的字符串转化为16进制字符串
        return b2a_hex(self.ciphertext)

    #解密后，去掉补足的空格用strip() 去掉
    def decrypt(self, text):
        cryptor = AES.new(self.key, self.mode, self.key)
        plain_text = cryptor.decrypt(a2b_hex(text))
        return plain_text.rstrip('\0')


