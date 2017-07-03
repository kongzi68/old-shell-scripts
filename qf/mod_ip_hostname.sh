#!/bin/bash
#Auto modify ip and hostname
#by colin on 2015-05-07

IP_CONFIG='/etc/sysconfig/network-scripts/ifcfg-eth0'
HOSTNAME_CONFIG='/etc/sysconfig/network'
HOSTS_CONFIG='/etc/hosts'
BACK_DIR="/data/backup/`date +%Y%m%d`"
#定义一个IP主要内容数组
a=0  #定义变量a为数组的下标，动态使用的时候调用IP_ARRAY[a]
IP_ARRAY=(
IPADDR
NATMASK
GATEWAY
dns1
dns2
)

#判断IP是否符合标准规则
function judge_ip(){
	#这里local $1出错，用2>/dev/null屏蔽掉错误，暂未发现影响输出结果
	local $1 2>/dev/null
	TMP_TXT=/tmp/iptmp.txt
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
            read -n 1 -p "输入${IP_ARRAY[a]}的值是${IP_ADDR},确认输入：Y|y；重新输入：R|r：" OK
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
#取得正确的IP值
#通过调用函数judge_ip，变量IP_ADDR的最终值就是正确的
function read_right_IP(){
	read -p "请输入${IP_ARRAY[a]}的值：" IP_ADDRS
#	IP_ADDRS=""
    judge_ip "${IP_ADDRS}";
    i=`echo $?`
    #循环直到输入正确的IP为止
    until [ "$i" -eq 0 ];do
        echo -e "\033[31m\n你输入了错误的${IP_ARRAY[a]}值：${IP_ADDRS} ====>>>>\033[0m" 
        read -p "重新输入${IP_ARRAY[a]}，请输入：" IP_ADDRS
        judge_ip "${IP_ADDRS}";
        i=`echo $?`
    done
}
#判断网卡配置文件，存在就备份，不存在则新建一个空白文件
function chang_ip(){
	if [ -f ${IP_CONFIG} ];then
		#备份原网卡配置文件
		if [ ! -d ${BACK_DIR} ];then
			mkdir -p ${BACK_DIR} && cp ${IP_CONFIG} ${BACK_DIR}/ip_config_`date +%Y%m%d`.bak
		fi
		#网卡的MAC地址
		HW_ADDR=`grep 'HWADDR' ${IP_CONFIG}`
		#IP配置状态
		DHCP_STATUS=`grep 'BOOTPROTO' ${IP_CONFIG} |awk -F= '{print toupper($2)}'`
		#如果BOOTPROTO的值是DHCP，就继续设置IP，否则退出呢
		if [ "${DHCP_STATUS}" = 'DHCP' ];then
			echo -e "\033[32mIP获取方式为：${DHCP_STATUS}，下面将修改为静态IP...\033[0m"
			rm -rf ${IP_CONFIG} && touch ${IP_CONFIG};
#把部分基本信息导入到网卡配置文件内
cat >${IP_CONFIG} <<EOF
DEVICE=eth0
HWADDR
TYPE=Ethernet
ONBOOT=yes
BOOTPROTO=static
EOF
##########################################
			#把原来MAC地址写进去
			sed -i "/HWADDR/s/HWADDR/${HW_ADDR}/g" ${IP_CONFIG}
			#循环五次，共调用函数五次，分别获取需要设置的所有数据
			for ((a=0;a<=4;a++))
			do
				read_right_IP;
				echo -e "\033[32m\n${IP_ARRAY[a]}=${IP_ADDRS}\033[0m"
				#把内容追加到网卡配置文件的最后
				echo -e "${IP_ARRAY[a]}=${IP_ADDRS}" >> ${IP_CONFIG}
			done
			echo -e "\033[32m\n+++++++设置的IP相关信息如下+++++++\033[1m"
			cat ${IP_CONFIG};
			echo -e "\033[32m\n++++++++++++++++++++++++++++++++++\033[0m"
		else
			echo -e "\033[32m系统IP已经是：${DHCP_STATUS}，无须修改...\033[0m" 
		fi
	else
		echo -e "\033[31m网卡配置文件：${IP_CONFIG}不存在，请检查系统是否被破坏...\033[0m" 
	fi
}
#脚本选择菜单
menu=(
	chang_ip_config
	chang_hostname_config
	chang_hosts_confg
	exit_menu
	help_menu
)
PS3="Please select menu will running to do (Need help,Please input: 5 ): "
select i in ${menu[@]}
do
	case $i in
		${menu[0]})
			chang_ip
			if [ "$?" -eq 0 ];then
				echo -e "\033[32m修改IP为静态获取成功...\033[0m" 
			else
				echo -e "\033[31m请检查IP是否为静态获取...\033[0m" 
			fi
		;;
		${menu[1]}) exit ;;
		${menu[2]}) exit ;;
		${menu[3]}) exit ;;
		${menu[4]})
			echo -e "\033[32m=========帮助菜单内容如下==========\033[0m" 
			
			for ((i=0;i<"${#menu[@]}";i++))
			do
				echo -e "\033[33m `expr $i + 1`) ${menu[i]} \033[0m"
			done
		;;
	esac
done

