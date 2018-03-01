#coding=utf-8
import logging
import os
import paramiko
import time
from retrying import retry
from .libs.libdb import getMysqlData, getMysqlConn

logger = logging.getLogger(__name__)


class ScriptsExec(object):
    def __init__(self, id, ip, port, user, password, log):
        super(ScriptsExec, self).__init__()
        self.scripts_id = id
        self.ip = ip
        self.user = user
        self.port = port
        self.password = password
        self.log = log    # web脚本的log
        self.log_nums = 0
        self.tools = Tools(self.ip, self.port, self.user, self.password)
        self.nano_seconds = format(time.time(),'0.10f')
        self.tmp_strings = "".join(str(self.nano_seconds).split('.'))
        self.screen_name = 'run_web_scripts'
        self.log_name = '/var/log/{0}.log'.format(self.screen_name)   # 临时脚本产生的log文件
        self.tmp_script_name = "exec_scripts_{0}.sh".format(self.tmp_strings)
        self.temp_script_dst = '/tmp/{0}'.format(self.tmp_script_name)
        self.mysql_conn = getMysqlConn()


    def check_env(self):
        """ 安装与检查screen命令是否存在 """
        scripts_name = "install_screen.sh"
        src = "swamp/main/{0}".format(scripts_name)
        dst = "/tmp/{0}".format(scripts_name)
        commands = "sh {0}".format(dst)
        tran_status = self.tools.transfer_file(src, dst)
        if tran_status:
            logger.debug(u"传送脚本成功")
            stdout = self.tools.exec_command(commands, isreturnlog=True)
            logger.debug(stdout.rstrip())
            cmd_status = bool(int(stdout))
            if cmd_status:
                logger.debug(u"命令screen已准备好.")
                self.tools.exec_command("cd /tmp && rm -f {0}".format(scripts_name))
                return True
            else:
                logger.error(u"安装screen命令失败，请检查.")
                return False
        else:
            logger.error(u"传送脚本 {0} 失败.".format(scripts_name))
            return False

    def exec_scripts(self, commands):
        """
        通过screen运行临时脚本，临时脚本中装载需要执行的 commands
        :param commands: web页面传过来，需要在后台运行的命令
        :return:
        """
        env_status = self.check_env()
        if env_status:
            # 检查脚本是否处于锁定状态
            sql_select = "SELECT `status` FROM t_scripts WHERE id={0};".format(self.scripts_id)
            q_result = getMysqlData(query=sql_select,dict_ret=True)
            if q_result:
                scripts_status = bool(int(q_result[0].get('status')))
                if scripts_status:
                    logger.info(u"脚本正在运行，当前为重复提交执行，已无视该次操作！")
                    return 'running'
            ######################################
            # 网络连接中断导致的screen未清理掉
            try:
                check_commands = "screen -ls|grep 'Detached'|awk -F. '{print $1}'"
                check_result = self.tools.exec_command(check_commands, isreturnlog=True)
                screen_list = check_result.split('\n')
                for item in screen_list:
                    self.tools.exec_command("screen -X -S {0} quit".format(item.strip()))
            except Exception as err:
                logger.error(err)
                pass
            # 清理脚本
            self.tools.exec_command("cd /tmp && find . -type f -name 'exec_scripts_*.sh' -delete")
            ######################################
            # 创建脚本
            with open(self.tmp_script_name, 'wb') as f:
                f.write('#!/usr/bin/env bash\n\n')
                f.write('{0}\n'.format(commands))
                f.write('screen -X -S {0} quit\n'.format(self.screen_name))
                f.flush()
            f.close()
            # 传送脚本
            tran_status = self.tools.transfer_file(self.tmp_script_name, self.temp_script_dst)
            if tran_status:
                # 在脚本运行前,获取web脚本日志最后一条的行号
                get_log_num_commands = "[ ! -f {0} ] && touch {0};wc -l {0}".format(self.log) + "|awk '{print $1}'"
                logger.debug(get_log_num_commands)
                stdout_get_log_num = self.tools.exec_command(get_log_num_commands, isreturnlog=True)
                if int(stdout_get_log_num) > 0:
                    self.log_nums = int(stdout_get_log_num) + 1
                else:
                    self.log_nums = 1
                logger.error(self.log_nums)
                cur = self.mysql_conn.cursor()
                sql_update = "UPDATE t_scripts SET log_start_num = {0} WHERE id = {1};".format(
                    self.log_nums, self.scripts_id)
                cur.execute(sql_update)
                # test_log = self.tools.exec_command('cat /tmp/test.log', isreturnlog=True)
                # logger.error(test_log)
                if os.path.exists(self.tmp_script_name):
                    os.remove(self.tmp_script_name)
                # 通过screen后台运行临时脚本
                screen_commands = '''
                    screen -dmS {0} &&
                    screen -x -S {0} -p 0 -X stuff "sh -x {1} >> {2} 2>&1 `echo -ne '\015'`"
                    '''.format(self.screen_name, self.temp_script_dst, self.log_name)
                logger.error(screen_commands)
                self.tools.exec_command(screen_commands)
                time.sleep(2)
                logger.info(u"已通过screen运行临时脚本：{0}".format(self.tmp_script_name))
                # 脚本开始运行后，把status设置为1锁定脚本，禁止脚本再次启动
                sql_update = "UPDATE t_scripts SET `status` = 1 WHERE id = {0};".format(self.scripts_id)
                cur.execute(sql_update)
                self.mysql_conn.commit()
                return True
            else:
                logger.error(u"传送临时脚本：{0} 失败.".format(self.tmp_script_name))
                return False
        else:
            return False

    def get_scripts_logs(self, log_num, logname, log_queue):
        """
        抓取日志内容
        :return:
        """
        star_num = log_num
        get_log_status = True
        while get_log_status:
            time.sleep(2)
            # 取回log数据
            try:
                command_get_log = "sed -n '{0}".format(star_num) + ",$ p'" +" {0}".format(logname)
                logger.debug(command_get_log)
                stdout_log = self.tools.exec_command(command_get_log, isreturnlog=True)
                command_get_porc = "ps -ef |grep '{0}' |wc -l".format(self.tmp_script_name)
                stdout_porc = self.tools.exec_command(command_get_porc, isreturnlog=True)
                if stdout_porc is None:
                    # 网络正常时，就算进程不存在，stdout_porc的值也会>=1
                    # raise Exception('Network Interruption')
                    # logger.error(u"网络中断了")
                    pass
                porc_num = int(stdout_porc)
                stdout_log_len = len(stdout_log)
            except Exception as err:
                porc_num = 0
                stdout_log = None
                stdout_log_len = 0
                logger.error(err)
                logger.error(u"网络中断了")
            if stdout_log_len > 0:
                # logger.debug(stdout_log)
                t_log = stdout_log.rstrip().split('\n')
                for log_line in t_log:
                    log_line = log_line.rstrip()
                    log_queue.put(log_line)
                    logger.debug(log_line)
                t_log_num = len(t_log)
                star_num += t_log_num
            else:
                t_log_num = 0
            if t_log_num == 0 and int(porc_num) == 2:
                # 日志取完之后，给队列在put一个None对象，用于当从队列中get的数据为None时，跳出while循环
                log_queue.put('normal_stop')
                get_log_status = False
                logger.debug(u"触发：正常退出")
            elif t_log_num == 0 and int(porc_num) == 0:
                log_queue.put('network_interruption') # 加入作为判断网络中断的信息
                # get_log_status = False
                logger.debug(u"网络中断退出")
            logger.debug(u"临时脚本进程数：{0};日志数量：{1};日志名称：{2}".format(porc_num, t_log_num, logname))
        # 清理临时脚本与其产生的日志文件
        if logname == self.log_name:
            self.tools.exec_command('cd /var/log && rm {0}.log -f'.format(self.screen_name))
        elif logname == self.log:
            self.tools.exec_command('cd /tmp && rm {0} -f'.format(self.tmp_script_name))
            # 脚本获取日志完成后，把status设置为0，解除锁定脚本
            try:
                sql_update = "UPDATE t_scripts SET `status` = 0 WHERE id = {0};".format(self.scripts_id)
                cur = self.mysql_conn.cursor()
                cur.execute(sql_update)
                self.mysql_conn.commit()
            except Exception as err:
                logger.error(err)
            finally:
                self.mysql_conn.close()


class Tools(object):
    """
    工具集
    :param password=None时，使用key
    """
    def __init__(self, ip, port, user, password=None):
        super(Tools, self).__init__()
        self.ip = ip
        self.user = user
        self.port = port
        self.password = password
        self.key_file = 'swamp/config/id_rsa'

    # 连接重试10次
    # TODO(colin): 目前这里感觉有问题，但后来测试又重试成功了
    def create_ssh(self, invoke=False):
        @retry(stop_max_attempt_number=10, wait_random_min=5000, wait_random_max=10000)
        def _create_ssh(invoke):
            """
            这两种方式，具体为啥这样，还需要细读官方文档
            :param invoke:
                True：交互式，返回 channel; channel.send("command")
                False：非交互式，返回 [channel, client]；
                    channel.exec_command("command")  在后台执行，无任何输出？
                    client.exec_command("command")   有标准输出与标准错误输出
                        stdin, stdout, stderr = client.exec_command(command)
            :return:
            """
            key = paramiko.RSAKey.from_private_key_file(self.key_file)
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            try:
                if self.password:
                    client.connect(hostname=self.ip, port=self.port, username=self.user,
                                   password=self.password, timeout=10, auth_timeout=10)
                    logger.debug(u"用密码登录")
                else:
                    client.connect(hostname=self.ip, port=self.port, username=self.user, pkey=key, timeout=10, auth_timeout=10)
                    logger.debug(u"用key登录")
                logger.info('connection success.')
                channel = client.get_transport().open_session()
                if invoke:
                    channel.get_pty()
                    channel.invoke_shell()
                    return channel
                else:
                    return [channel, client]
            except (paramiko.AuthenticationException,
                    paramiko.BadHostKeyException,
                    paramiko.SSHException,
                    Exception) as err:
                logger.error(err)
                logger.error('connection failed...')
                raise Exception('Network Interruption')
                # return None
        return _create_ssh(invoke)

    def transfer_file(self, src, dst, isput=True):
        """ 非交互式 """
        ssh_conn = self.create_ssh()
        if ssh_conn:
            _, ssh = ssh_conn
            try:
                t = ssh.get_transport()
                sftp = paramiko.SFTPClient.from_transport(t)
                if isput:
                    sftp.put(src, dst)
                else:
                    sftp.get(src, dst)
                t.close()
                return True
            except Exception as err:
                logger.error(err)
                return False
            finally:
                ssh.close()
        else:
            return None

    def exec_command(self, command, isreturnlog=False):
        """
        非交互式：执行一次命令，返回结果，关闭连接
        """
        ssh_conn = self.create_ssh()
        if ssh_conn:
            _, ssh = ssh_conn
            try:
                if isreturnlog:
                    _, stdout, _ = ssh.exec_command(command)
                    return stdout.read()
                else:
                    ssh.exec_command(command)
                    return True
            except Exception as err:
                logger.error(err)
                return False
            finally:
                ssh.close()
        else:
            return None

    def exec_command_and_getlog(self, command):
        """
        非交互式：执行一次命令，返回结果，关闭连接
        """
        ssh_conn = self.create_ssh()
        if ssh_conn:
            _, ssh = ssh_conn
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
            except Exception as err:
                logger.error(err)
                return err
            finally:
                ssh.close()
        else:
            return None

    def exec_command_invoke(self, command):
        """
        交互式：
        """
        channel = self.create_ssh(invoke=True)
        if channel:
            pass
        else:
            return None
