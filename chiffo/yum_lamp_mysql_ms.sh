#!/bin/bash
#select menu yum install lamp and mysql master_slave
#by colink in 2015-04-28,05-13
#version v.c.m.0.3

BACKUP_DIR="/data/backup/`date +%Y%m%d`/"
IPADDR=`ifconfig eth0|grep Bcast |awk '{print $2}'|sed 's/addr://g'`

#判断IP是否符合标准规则
function judge_ip(){
    #这里local $1出错，用2>/dev/null屏蔽掉错误，暂未发现影响输出结果
    local $1 2>/dev/null
    TMP_TXT='/tmp/iptmp.txt'
    echo $1 > ${TMP_TXT}
    IP_ADDR=`grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' ${TMP_TXT}`
    #判断有没有符合***.***.***.***规则的IP
    if [ ! -z "${IP_ADDR}" ];then
        local j=0;
        #通过循环来检测每个点之前的数值是否符合要求
        for ((i=1;i<=4;i++))
        do
            local IP_NUM=`echo "${IP_ADDR}" |awk -F. "{print $"$i"}"`
            #判断IP_NUM是否在0与255之间
            if [ "${IP_NUM}" -ge 0 -a "${IP_NUM}" -le 255 ];then
                ((j++));
            else
                return 1
            fi
        done
        #通过j的值来确定是否继续匹配规则，循环四次，若都正确j=4.
        if [ "$j" -eq 4 ];then
            #确认是否为自己想要输入的IP地址
            read -n 1 -p "输入IP地址是${IP_ADDR},确认输入：Y|y；重新输入：R|r：" OK
            case ${OK} in
                Y|y) rm -rf ${TMP_TXT} ; return 0;;
                R|r) return 1;;
                *) return 1;;
            esac
        else
            return 1
        fi
    else
        return 1
    fi
}

#初始化系统，安装vi等，关闭防火墙和selinux
function init_system_environment(){
	echo -e "\033[32mNow,Will begin initialization system,Please wait...\033[0m"
	yum -y install cmake vim wget lrzsz unzip man ntpdate gcc* \
autoconf libtool python-devel libXpm-devel ncurses-devel git
	echo "alias vi='vim'" >>/root/.bashrc ; source /root/.bashrc ;
	chkconfig --level 3 iptables off ; chkconfig --level 3 ip6tables off
	ntpdate pool.ntp.org
	sed -i "/^SELINUX=enforcing/s/enforcing/disabled/g" /etc/selinux/config
	if [ $? -eq 0 ];then
		echo -e "\033[32mINIT ststem done. Will reboot system, Input Y|y or N|n :\033[0m"
		read -n 1 do_reboot
		case ${do_reboot} in
			Y|y) init 6 ;;
			N|n) break ;;
		esac
	fi
}
#定义依赖包安装函数是否运行的状态
DEPEND_STATUS=1
#DEPEND_STATUS=0时，表示已经运行过；等于1时，表示未运行
#yum安装lamp需要的各种包函数
function install_depend(){
    yum -y install zlib zlib-devel libpng libpng-devel freetype \
freetype-devel libart_lgpl libart_lgpl-devel libxml2 libxml2-devel \
cairo cairo-devel pango pango-devel perl-devel \
cjkuni-ukai-fonts.noarch  cjkuni-uming-fonts.noarch
}
#YUM 安装apache
function install_apache(){
	if [ ${DEPEND_STATUS} -eq 1 ];then
		install_depend;
		if [ $? -eq 0 ];then
			${DEPEND_STATUS}=0;
		fi
	fi
	echo -e "\033[32mWill yum install apache,Please wait...\033[0m"
	yum -y install apr apr-devel httpd httpd-devel
	if [ $? -eq 0 ];then
		echo -e "\033[32mThe apache was installed successfully...\033[0m"
	else
		echo -e "\033[31mThe apache was installed failed,Please check...\033[0m"
    fi
}
#YUM 安装PHP
function install_php(){
    if [ ${DEPEND_STATUS} -eq 1 ];then
        install_depend;
        if [ $? -eq 0 ];then
            ${DEPEND_STATUS}=0;
        fi
    fi
    echo -e "\033[32mWill yum install php,Please wait...\033[0m"
    yum -y install gd gd-devel php php-devel php-mysql php-gd \
php-mbstring php-pear php-pecl* php-xml php-xmlrpc php-snmp php-soap
    if [ $? -eq 0 ];then
        echo -e "\033[32mThe PHP was installed successfully...\033[0m"
    else
        echo -e "\033[31mThe PHP was installed failed,Please check...\033[0m"
    fi
}
#YUM 安装mysql
function install_mysql(){
    echo -e "\033[32mWill yum install mysql,Please wait...\033[0m"
	yum -y install mysql mysql-server mysql-devel
    if [ $? -eq 0 ];then
        echo -e "\033[32mThe mysql was installed successfully...\033[0m"
		service mysqld restart;
    else
        echo -e "\033[31mThe mysql was installed failed,Please check...\033[0m"
    fi
}
#整合apache与PHP的配置函数
HTTPD_CONF='/etc/httpd/conf/httpd.conf'
HTTPD_HTML_DIR='/var/www/html/'
CHECK_PHP_FILES='phpinfo.php'
function mod_httpd_conf(){
	echo -e "\033[32mWill Modify httpd.conf Profile,Please wait...\033[0m"
	sleep 3
	if [ ! -d ${BACKUP_DIR} ];then
		mkdir -p ${BACKUP_DIR}
	fi
	cp ${HTTPD_CONF} ${BACKUP_DIR}httpd`date +%Y%m%d%k%M%S`.conf
	sed -i "/#ServerName/s/#//g" ${HTTPD_CONF} ;
	sed -i "/Options Indexes FollowSymLinks/s/Indexes//g" ${HTTPD_CONF} ;
	sed -i "/DirectoryIndex index.html index.html.var/s/DirectoryIndex/\
DirectoryIndex index.php/g" ${HTTPD_CONF} ;
	echo "Addtype application/x-httpd-php  .php  .phtml" >> ${HTTPD_CONF} ;
	echo -e "\033[32mModify httpd.conf profile done.\033[0m"
	#create phpinfo.php for check PHP
	cat >${HTTPD_HTML_DIR}${CHECK_PHP_FILES} <<EOF
<?php
phpinfo();
?>
EOF
	if [ -f ${HTTPD_HTML_DIR}${CHECK_PHP_FILES} ];then
		/etc/init.d/httpd restart 2>&1
		if [ $? -eq 0 ];then
			echo -e "\033[32mPlease check PHP. Usage:  \
http://${IPADDR}/${CHECK_PHP_FILES}\033[0m"
		fi
	fi
}

#mysql主从服务搭建的函数
MYSQL_USER='root'
MYSQL_PASSWORD='123456'
SYNC_USER='tongbu'
SYNC_PASSWORD='123456'
MYSQL_CONF='/etc/my.cnf'
BINLOG_NODE='/tmp/binlog.txt'
#define mysql master function
function mysql_master(){
	MYSQL_RUN_STATUS=`ps -ef |grep "mysql" |grep -Ev "grep|lamp" |wc -l`
	echo -e "\033[32m=============================================\033[0m"
	echo -e "\033[32mPlease waiting,ntpdate is working...\033[0m"
	ntpdate pool.ntp.org
	sleep 1
    if [ "${MYSQL_RUN_STATUS}" -eq 0 ];then
        echo -e "\033[32mThe mysql didn't installed,Now running install_mysql ...\033[0m"
		install_mysql;
    fi
	if [ ! -d ${BACKUP_DIR} ];then
        mkdir -p ${BACKUP_DIR}
    fi
    cp ${MYSQL_CONF} ${BACKUP_DIR}my`date +%Y%m%d%k%M%S`.conf
	#导入my.cnf配置文件内容
	cat >${MYSQL_CONF} <<EOF
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql
symbolic-links=0
log-bin=mysql-bin
server-id=1
auto_increment_offset=1
auto_increment_increment=2
[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
replicate-do-db=all
EOF
	echo -e "\033[32mThe mysql master is starting,please wait...\033[0m"
	sleep 1
	rm -rf ${BINLOG_NODE}
	find /var/lib/mysql/ -name "*mysql-bin*" -exec rm -rf {} \;;
	/etc/init.d/mysqld restart
	if [ "${MYSQL_RUN_STATUS}" -gt 0 ];then
	    echo -e "\033[32mThe mysql master was started successfully...\033[0m"
	else
		echo -e "\033[31mThe mysql master was started failed, Please check...\033[0m"
	    exit;
	fi
	sleep 1
	mysqladmin -u${MYSQL_USER} password ${MYSQL_PASSWORD}
	mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "delete from mysql.user where User='';"
	mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "grant replication slave on *.* \
to '$SYNC_USER'@'%' identified by '$SYNC_PASSWORD';flush privileges;"
	#定义binlog日志变量
	BINLOGNAME=`mysql  -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "show master \
status \G" |grep File |awk '{print $2}'`
	BINLOGNODE=`mysql  -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "show master \
status \G" |grep Position |awk '{print $2}'`
	echo "BINLOGNAME=$BINLOGNAME" >> ${BINLOG_NODE}
	echo "BINLOGNODE=$BINLOGNODE" >> ${BINLOG_NODE}
	echo "MASTER_IP=`ifconfig eth0|grep Bcast |awk '{print $2}'|sed 's/addr://g'`" >> ${BINLOG_NODE}
	echo -e "\033[32m拷贝binlog相关信息到slave主机上，请按提示输入相应的内容。\033[0m"
	read -p "Please input mysql-slave IPADDR: " SLAVE_IP
	#判断输入的IP是否合法
	judge_ip ${SLAVE_IP};
	until [ $? -eq 0 ];do
		read -p "Error IPADDR, Please input mysql-slave IPADDR again: " SLAVE_IP
		judge_ip ${SLAVE_IP};
	done
	echo 
	scp ${BINLOG_NODE} /root/$0 root@${SLAVE_IP}:/root/
	if [ $? -eq 0 ];then
	    echo 
	    echo -e "\033[32m已成功拷贝到mysql-slave，IP:${SLAVE_IP}的/root/下\033[0m"
	fi
}
#define mysql-slave function
function mysql_slave(){
    MYSQL_RUN_STATUS=`ps -ef |grep "mysql" |grep -Ev "grep|lamp" |wc -l`
    echo -e "\033[32m=============================================\033[0m"
    echo -e "\033[32mPlease waiting,ntpdate is working...\033[0m"
    ntpdate pool.ntp.org
    sleep 1
    if [ "${MYSQL_RUN_STATUS}" -eq 0 ];then
        echo -e "\033[32mThe mysql didn't installed,Now running install_mysql ...\033[0m"
        install_mysql;
    fi
    if [ ! -d ${BACKUP_DIR} ];then
		mkdir -p ${BACKUP_DIR}
    fi
    cp ${MYSQL_CONF} ${BACKUP_DIR}my`date +%Y%m%d%k%M%S`.conf
    #导入my.cnf配置文件内容
    cat >${MYSQL_CONF} <<EOF
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql
symbolic-links=0
#log-bin=mysql-bin
server-id=2
auto_increment_offset=2
auto_increment_increment=2
[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
replicate-do-db=all
EOF
    echo -e "\033[32mThe mysql-slave is starting,please wait...\033[0m"
    sleep 1
    /etc/init.d/mysqld restart
    if [ "${MYSQL_RUN_STATUS}" -gt 0 ];then
        echo -e "\033[32mThe mysql-slave was started successfully...\033[0m"
    else
        echo -e "\033[31mThe mysql-slave was started failed, Please check...\033[0m"
		exit;
    fi
    sleep 1
    mysqladmin -u${MYSQL_USER} password ${MYSQL_PASSWORD}
	mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "delete from mysql.user where User='';"
    BINLOGNAME=`cat /root/binlog.txt |grep "BINLOGNAME" | awk '{print $1}' |sed 's/BINLOGNAME=//g'`
    BINLOGNODE=`cat /root/binlog.txt |grep "BINLOGNODE" | awk '{print $1}' |sed 's/BINLOGNODE=//g'`
    MASTER_IP=`cat /root/binlog.txt |grep "MASTER_IP" | awk '{print $1}' |sed 's/MASTER_IP=//g'`
    mysql  -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "change master to master_host='$MASTER_IP',\
master_user='$SYNC_USER',master_password='$SYNC_PASSWORD',master_log_file='$BINLOGNAME',\
master_log_pos=$BINLOGNODE;start slave;"
    #check start status;
    SLAVE_IO_STATUS=`mysql  -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "show slave status \
\G" |grep Slave_IO_Running | awk '{print $2}'`
    SLAVE_SQL_STATUS=`mysql  -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "show slave status \
\G" |grep Slave_SQL_Running | awk '{print $2}'`
    echo 
    echo -e "\033[32m\n--------------------------\033[0m"
    if [ "$SLAVE_IO_STATUS" = 'Yes' -a "$SLAVE_SQL_STATUS" = 'Yes' ];then
         echo -e "\033[32mThe mysql master-slave was installed sucessfuly!\033[0m"
    else
         echo -e "\033[32mThe mysql master-slave can't start,Please check ... \033[0m"
    fi
}
#功能选择菜单
menu=(
	init_system_environment
	install_apache
	install_php
	install_mysql
	mod_httpd_conf
	mysql_master
	mysql_slave
	exit_menu
	help_menu
)
#因为习惯性的把help放在最后，所以这里用${#menu[@]}
PS3="Please select menu will running to do (Need help,Please input: ${#menu[@]} ): "
select i in ${menu[@]}
do
	case $i in
	${menu[0]}) ${menu[0]} ;;
	${menu[1]}) ${menu[1]} ;;
	${menu[2]}) ${menu[2]} ;;
	${menu[3]}) ${menu[3]} ;;
	${menu[4]}) ${menu[4]} ;;
	${menu[5]}) ${menu[5]} ;;
	${menu[6]}) ${menu[6]} ;;
	${menu[7]}) exit ;;
	${menu[8]})
		echo -e "\033[32m=========帮助菜单内容如下==========\033[0m"
		for ((i=0;i<"${#menu[@]}";i++))
		do
			echo -e "\033[33m `expr $i + 1`) ${menu[i]} \033[0m"
		done
		;;
	esac
done


