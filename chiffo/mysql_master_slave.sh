#!/bin/bash
#auto install mysql master and slave
#by colink in 2015-04-28


echo -e "\033[32m---------------------------------\033[0m"

IPADDR=`ifconfig |grep Bcast |awk '{print $2}'|sed 's/addr://g'`
MASTER_IP=192.168.2.230
SYNC_USER='tongbu'
SYNC_PASSWORD='123456'

sleep 2
if [ "$IPADDR" = "192.168.2.230" ] ;then
	echo -e "\033[32mInstall mysql master\033[0m"
	yum -y install ntpdate mysql-server mysql-devel mysql
	echo -e "\033[32mPlease waiting,ntpdate is working...\033[0m"
	ntpdate pool.ntp.org
	sleep 3
	rm -rf /etc/my.cnf
	echo "" > /etc/my.cnf
	sed -i  '1a\[mysqld]\ndatadir=/var/lib/mysql\nsocket=/var/lib/mysql/mysql.sock\nuser=mysql\nsymbolic-links=0\nlog-bin=mysql-bin\nserver-id=1\nauto_increment_offset=1\nauto_increment_increment=2\n\n[mysqld_safe]\nlog-error=/var/log/mysqld.log\npid-file=/var/run/mysqld/mysqld.pid\nreplicate-do-db=all' /etc/my.cnf
	echo -e "\033[32mMysql master is starting,please wait...\033[0m"
	sleep 1
	/etc/init.d/mysqld restart
	if test $? -eq 0;then
	    echo -e "\033[32mMysql master was started successfully...\033[0m"
	else
	    exit
	fi
#	sleep 1
	echo -e "\033[32m请输入mysql初始密码，密码为空，直接按回车键即可！ \033[0m"
	mysqladmin -hlocalhost -uroot -p password 123456
	mysql -hlocalhost -uroot -p123456 -e "grant replication slave on *.* to '$SYNC_USER'@'%' identified by '$SYNC_PASSWORD';flush privileges;"

	#定义binlog日志变量
	BINLOGNAME=`mysql -hlocalhost -uroot -p123456 -e "show master status \G" |grep File |awk '{print $2}'`
	BINLOGNODE=`mysql -hlocalhost -uroot -p123456 -e "show master status \G" |grep Position |awk '{print $2}'`
	echo "BINLOGNAME=$BINLOGNAME" >> /tmp/binlog.txt
	echo "BINLOGNODE=$BINLOGNODE" >> /tmp/binlog.txt
	echo -e "\033[32m拷贝binlog相关信息到slave主机上，请按提示输入yes和密码...\033[0m"
	scp /tmp/binlog.txt /root/$0 root@"192.168.2.231":/root/
	if [ $? -eq 0 ];then
	    echo 
	    echo -e "\033[32m已成功拷贝到192.168.2.231的/root/下\033[0m"
	fi
	rm -rf /tmp/binlog.txt
			
else
	echo -e "\033[32mInstall mysql slave\033[0m"
	yum -y install ntpdate mysql-server mysql-devel mysql
	echo -e "\033[32mPlease waiting,ntpdate is working...\033[0m"
	ntpdate pool.ntp.org
	sleep 3
	rm -rf /etc/my.cnf
	echo "" > /etc/my.cnf
	sed -i '1a\[mysqld]\ndatadir=/var/lib/mysql\nsocket=/var/lib/mysql/mysql.sock\nuser=mysql\nsymbolic-links=0\nserver-id=2\nauto_increment_offset=2\nauto_increment_increment=2\n\n[mysqld_safe]\nlog-error=/var/log/mysqld.log\npid-file=/var/run/mysqld/mysqld.pid\nreplicate-do-db=all' /etc/my.cnf
	/etc/init.d/mysqld restart
        if [ $? -eq 0 ];then
            echo -e "\033[32mMysql slave was started successfully...\033[0m"
        else
            exit
        fi
	sleep 1
	echo -e "\033[32m请输入mysql初始密码，密码为空，直接按回车键即可！ \033[0m"
	mysqladmin -hlocalhost -uroot -p password 123456

	BINLOGNAME=`cat /root/binlog.txt |grep BINLOGNAME | awk '{print $1}' |sed 's/BINLOGNAME=//g'`
	BINLOGNODE=`cat /root/binlog.txt |grep BINLOGNODE | awk '{print $1}' |sed 's/BINLOGNODE=//g'`

	mysql -hlocalhost -uroot -p123456 -e "change master to master_host='$MASTER_IP',master_user='$SYNC_USER',master_password='$SYNC_PASSWORD',master_log_file='$BINLOGNAME',master_log_pos=$BINLOGNODE;start slave;"
	
	#check start status;
	SLAVE_IO_STATUS=`mysql -hlocalhost -uroot -p123456 -e "show slave status \G" |grep Slave_IO_Running | awk '{print $2}'`
	SLAVE_SQL_STATUS=`mysql -hlocalhost -uroot -p123456 -e "show slave status \G" |grep Slave_SQL_Running | awk '{print $2}'`
	echo 
	echo -e "\033[32m\n--------------------------\033[0m"
	if [ "$SLAVE_IO_STATUS" = 'Yes' -a "$SLAVE_SQL_STATUS" = 'Yes' ];then
	     echo -e "\033[32mThe mysql master-slave was installed sucessfuly!\033[0m"
	else
	     echo -e "\033[32mThe mysql master-slave can't start,Please check ... \033[0m"
	fi

fi

