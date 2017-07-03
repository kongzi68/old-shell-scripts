#!/bin/bash
#auto drop ssh failed IP address 
#by colink on 2015-05-07

IPTAB_DIR='/etc/sysconfig/iptables'
LOG_DIR='/var/log/secure'
IPADDRS=`tail -n 200 ${LOG_DIR} |grep "Failed password" |grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' |sort -nr |uniq -c |awk '$1>=5 {print $2}'`
echo -e "\033[32m====================================\033[0m"
echo -e "\033[32mWill update the Iptables\033[0m"
echo -e "\033[32m------------------------------------\033[0m"
#判断iptables文件里面是否已经添加了该IP的规则
function add_iptables(){
	for i in ${IPADDRS}
	do
		IGREP=`grep "${i}" /etc/sysconfig/iptables`
		if [ -z "${IGREP}" ];then
			sed -i "/lo/a-A INPUT -s ${i} -m state --state NEW -m tcp -p tcp --dport 22 -j DROP" ${IPTAB_DIR}
			if [ $? -eq 0 ];then
				echo -e "\033[32m已成功将IP：${i}添加到防火墙...\033[0m"
			else
				echo -e "\033[31m添加IP：${i}的防火墙规则失败！\033[0m"
			fi
		else
			echo -e "\033[32m防火墙规则里已存在IP：${i}\033[0m"
#			exit 0
		fi
	done
}
#当有恶意IP的时候，添加到防火墙
if [ ! -z "${IPADDRS}" ];then
	add_iptables
else
    echo -e "\033[31m没有恶意登陆的IP...\033[0m"
    exit 0
fi
#重启iptables服务
/etc/init.d/iptables restart
echo -e "\033[32m====================================\033[0m"
