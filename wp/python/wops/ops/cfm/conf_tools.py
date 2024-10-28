#coding=utf-8
import copy
import logging
import os
import paramiko
import shutil
import re
import zipfile
from ..cfm.salt_top_sls import file_name
from ..libs.libdb import getMysqlData, cmdb_oss
from ..libs.common import str_code

logger = logging.getLogger(__name__)

# 1、传一个模版文件
# 2、传一份需要配置的数据：包含，服务器IP，需要动态替换的配置文件内容，配置文件路径
# 3、生成salt SLS
# 4、执行配置文件更新
# 5、检查更新后的配置文件

wops_conf_dir = 'ops/cfm/conf_data'


class CreateSLS(object):
    """
    创建SLS文件
    """
    def __init__(self, conf_groupid):
        super(CreateSLS, self).__init__()
        if conf_groupid is None:
            logger.error(u"未能获取到有效的config_id")
            return
        self.base_IamUsername = '/srv/salt'
        self.conf_groupid = conf_groupid
        self.sls_dir = '{0}/{1}'.format(wops_conf_dir, self.conf_groupid)
        self.sls_model_dir = '{0}/files'.format(self.sls_dir)
        if not os.path.exists(self.sls_model_dir):
            os.makedirs(self.sls_model_dir)
        self.conf_info = self.get_conf_info()
        if self.conf_info:
            self.conf_save_name = self.conf_info.get('conf_save_name')
            self.conf_name = self.conf_info.get('conf_name')
            self.game_id = self.conf_info.get('game_id')
            self.servers = self.conf_info.get('servers')
            self.conf_data = self.conf_info.get('conf_data')
        else:
            logger.error(u"未从cmdb_oss库查询到配置数据")
            return
        self.src = 'static/medias/{0}'.format(self.conf_save_name)
        self.dst = '{0}/{1}'.format(self.sls_model_dir, self.conf_name)
        self.file_name = '{0}/{1}'.format(self.sls_dir, file_name)
        self.master_top_scripts = 'salt_top_sls.py'
        self.scritps_file = 'ops/cfm/{0}'.format(self.master_top_scripts)


    def get_conf_info(self):
        query = "SELECT * FROM t_config WHERE id='{0}'".format(self.conf_groupid)
        logger.debug(query)
        ret = getMysqlData(cmdb_oss['host'],
                           cmdb_oss['port'],
                           cmdb_oss['user'],
                           cmdb_oss['passwd'],
                           cmdb_oss['dbname'],
                           query,
                           True)
        logger.debug(str(ret))
        if ret:
            return ret[0]
        else:
            return {}

    def get_dynamic_parameter(self, file_name):
        with open(file_name, 'rb') as f:
            content = f.read()
        matchobj = re.findall( r'{{\w+}}', content, re.M|re.I)
        t_ret = [ item[2:-2] for item in matchobj]
        logger.debug(str(t_ret))
        ret = []
        for item in t_ret:
            if item not in ret:
                ret.append(item)
        logger.debug(str(ret))
        return ret

    def get_saltids(self, serverids_str):
        serverids = "'{0}'".format(serverids_str.replace(',', "','"))
        query = "SELECT GROUP_CONCAT(saltid) AS saltids FROM t_server WHERE server_id in ({0});".format(serverids)
        q_ret = getMysqlData(query=query)
        saltids = q_ret[0][0]
        return saltids

    @staticmethod
    def strings_to_dict(strings):
        ret = {}
        confs = [ conf.strip() for conf in strings.split(';') if conf ]
        for conf in confs:
            conf = [ item.strip() for item in conf.split(',') if item ]
            logger.debug(str(conf))
            t_conf = copy.deepcopy(conf)
            t_conf.pop(0)
            ret.setdefault(conf[0], []).append(t_conf) # 这个用法好
        return ret

    def create_notop_sls(self):
        ret = {}
        if os.path.isfile(self.src):
            shutil.copyfile(self.src, self.dst)
        d_param = self.get_dynamic_parameter(self.dst)
        d_conf_data = self.strings_to_dict(self.conf_data)
        for server_id, conf_datas in d_conf_data.items():
            query = "SELECT saltid FROM t_server WHERE server_id='{0}';".format(server_id)
            q_ret = getMysqlData(query=query, dict_ret=True)
            if q_ret:
                saltid = q_ret[0].get('saltid')
            else:
                logger.error('The server_id: {0} is error, Please check.'.format(server_id))
                continue
            for x, conf_data in enumerate(conf_datas):
                # logger.info(str(conf_data))
                sls_file = '{0}/{1}_{2}.sls'.format(self.sls_dir, server_id, x)
                with open(sls_file, 'wb') as f:
                    # 定义SLS文件中的动态变量
                    for y, item in enumerate(d_param):
                        f.write("{% set " + item + "='{0}'".format(str_code(conf_data[y + 1])) + " %}\n")
                    f.write("\n")
                    # 设置需要被管理的文件
                    f.write("{0}:\n".format(conf_data[0]))
                    f.write("  file.managed:\n")
                    f.write("    - source: salt://{0}/files/{1}\n".format(self.conf_groupid, self.conf_name))
                    f.write("    - backup: minion\n")
                    f.write("    - template: jinja\n")
                    f.write("    - defaults:\n")
                    # 设置动态变量
                    for t_item in d_param:
                        f.write("      {0}: ".format(t_item) + "{{ "+ t_item +" }}\n")
                    f.flush()
                strins = '{0}.{1}'.format(self.conf_groupid, sls_file.split('/')[-1].split('.')[-2])
                ret.setdefault(saltid, []).append(strins)
        return ret

    def create_top_sls(self):
        sls_dict = self.create_notop_sls()
        logger.debug(str(sls_dict))
        # sls_dict = "{u'win2008_test': ['c5bc97e74b7b5367.1899e14ab77148ad_0'], u'iamIPaddress': ['c5bc97e74b7b5367.1a3ea89edf0a1dee_0', 'c5bc97e74b7b5367.1a3ea89edf0a1dee_1', 'c5bc97e74b7b5367.1a3ea89edf0a1dee_2'], u'iamIPaddress': ['c5bc97e74b7b5367.13799ff4c8113a06_0', 'c5bc97e74b7b5367.13799ff4c8113a06_1']}"
        with open(self.file_name, 'wb') as f:
            f.write(str(sls_dict))

    def push_sls(self):
        self.create_top_sls()
        tools = Tools(self.game_id)
        tools.zip_file(self.conf_groupid)
        dst_master_top_scripts = '{0}/{1}'.format(self.base_IamUsername, self.master_top_scripts)
        tools.transfer_file(self.scritps_file, dst_master_top_scripts)
        src_zip = '{0}/{1}.zip'.format(wops_conf_dir, self.conf_groupid)
        dst_zip = '{0}/{1}.zip'.format(self.base_IamUsername, self.conf_groupid)
        tools.transfer_file(src_zip, dst_zip)
        os.remove(src_zip)
        tools.exec_command('chmod +x {0}'.format(dst_master_top_scripts))

    def push_config(self, istest=True):
        """
        --out='json'
        Args:
            istest:

        Returns:

        """
        saltids = self.get_saltids(self.servers)
        tools = Tools(self.game_id)
        if istest:
            command_str = "salt -L '{0}' state.highstate test=True".format(saltids)
        else:
            command_str = "salt -L '{0}' state.highstate".format(saltids)
        logger.debug(command_str)
        ret = tools.exec_command(command_str)
        return ret

    def get_config(self, saltid, conf_path):
        """
        Args:
            saltid:
            conf_path:

        Returns:

        """
        tools = Tools(self.game_id)
        command_str = "salt -L '{0}' file.seek_read '{1}' 655355 0".format(saltid, conf_path)
        logger.debug(command_str)
        ret = tools.exec_command(command_str)
        return ret


class Tools(object):
    """
    远程运维工具
    """
    def __init__(self, game_id):
        super(Tools, self).__init__()
        self.game_id = game_id
        self.dir = wops_conf_dir
        self.ip, self.netip = self.get_master_ip()
        # self.ip = 'iamIPaddress'
        self.user = 'IamUsername'
        self.port = 22
        # self.key_file = os.environ.get('SSH_KEY_FILE')
        self.key_file = 'config/id_rsa'
        # self.know_host = '/IamUsername/.ssh/known_hosts'

    def get_master_ip(self):
        ret = []
        query = "SELECT server_id FROM t_saltmaster WHERE game_id='{0}';".format(self.game_id)
        q_ret = getMysqlData(query=query, dict_ret=True)
        server_id = q_ret[0].get('server_id')
        query = "SELECT ip, netip FROM t_server WHERE server_id='{0}';".format(server_id)
        q_ret = getMysqlData(query=query, dict_ret=True)
        ret.append(q_ret[0].get('ip'))
        ret.append(q_ret[0].get('netip'))
        return ret

    def zip_file(self, conf_groupid):
        ''' 压缩文件 '''
        try:
            import zlib
            compression = zipfile.ZIP_DEFLATED
        except:
            compression = zipfile.ZIP_STORED
        path = '{0}/{1}'.format(self.dir, conf_groupid)  #要进行压缩的文档目录
        start = path.rfind(os.sep) + 1
        filename = '{0}/{1}.zip'.format(self.dir, conf_groupid)  #压缩后的文件名
        z = zipfile.ZipFile(filename,mode = "w",compression = compression)
        try:
            for dirpath,dirs,files in os.walk(path):
                for file in files:
                    if file == filename or file == "zip.py":
                        continue
                    logger.info(file)
                    z_path = os.path.join(dirpath,file)
                    z.write(z_path,z_path[start:])
            z.close()
        except:
            if z:
                z.close()

    def unzip_file(self, filename, filedir):
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

    def create_ssh(self):
        key = paramiko.RSAKey.from_private_key_file(self.key_file)
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        # 使用内外网IP进行ssh连接
        try:
            ssh.connect(self.ip, username=self.user, pkey=key, timeout=10, auth_timeout=10)
            return ssh
        except Exception, err:
            try:
                ssh.connect(self.netip, username=self.user, pkey=key, timeout=10, auth_timeout=10)
                return ssh
            except Exception:
                # 若内外网IP都连接失败，输出第一次异常中的错误信息
                logger.error(err)
                return None

    def transfer_file(self, src, dst, isput=True):
        ssh = self.create_ssh()
        if ssh:
            logger.info('ssh connection success.')
        else:
            err = 'ssh connection failed...'
            logger.error(err)
            return err
        try:
            t = ssh.get_transport()
            sftp = paramiko.SFTPClient.from_transport(t)
            if isput:
                sftp.put(src, dst)
            else:
                sftp.get(src, dst)
            t.close()
        except (paramiko.AuthenticationException,
                paramiko.BadHostKeyException,
                paramiko.SSHException,
                Exception) as err:
            logger.error(err)
            return err
        finally:
            ssh.close()

    def exec_command(self, command):
        ssh = self.create_ssh()
        if ssh:
            logger.info('ssh connection success.')
        else:
            err = 'ssh connection failed...'
            logger.error(err)
            return err
        try:
            stdin, stdout, stderr = ssh.exec_command(command)
            ret_stdout = stdout.read()
            ret_stderr = stderr.read()
            logger.debug(ret_stdout)
            logger.debug(ret_stderr)
            if ret_stdout:
                return ret_stdout
            else:
                return ret_stderr
        except (paramiko.AuthenticationException,
                paramiko.BadHostKeyException,
                paramiko.SSHException,
                Exception) as err:
            logger.error(err)
            return err
        finally:
            ssh.close()