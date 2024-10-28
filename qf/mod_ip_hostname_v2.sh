#!/bin/bash
#Auto modify ip and hostname
#by colin on 2015-05-07,05-20

#网卡的MAC地址
MAC_ADDR=`ifconfig -a |grep eth|awk '{print $NF}' |tr [A-Z] [a-z]`
HW_ADDR="HWADDR=${MAC_ADDR}"
ETH_FILES='/etc/udev/rules.d/70-persistent-net.rules'
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
           read -n 1 -p "Input ${IP_ARRAY[a]} values is ${IP_ADDR}. \
Continue to input: Y|y ,Again to input: R|r " OK
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
	read -p "Please input ${IP_ARRAY[a]} values: " IP_ADDRS
#	IP_ADDRS=""
    judge_ip "${IP_ADDRS}";
    i=`echo $?`
    #循环直到输入正确的IP为止
    until [ "$i" -eq 0 ];do
        echo -e "\033[31m\nThe ${IP_ARRAY[a]} is false: ${IP_ADDRS} ====>>>>\033[0m" 
        read -p "Again to input ${IP_ARRAY[a]}, Please input: " IP_ADDRS
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
	#IP配置状态
	DHCP_STATUS=`grep 'BOOTPROTO' ${IP_CONFIG} |awk -F= '{print toupper($2)}'`
	#如果BOOTPROTO的值是DHCP，就继续设置IP，否则退出呢
	case ${DHCP_STATUS} in
		DHCP)
			echo -e "\033[32mThe BOOTPROTO is ${DHCP_STATUS}, Now to modify...\033[0m"
		;;
		STATIC)
			echo -e "\033[32m\033[1m" 
			read -n 1 -p "The BOOTPROTO is ${DHCP_STATUS}, Continue to input: Y|y ,Again to input: N|n :" ip_ok
			case ${ip_ok} in
				Y|y) echo -e "\nNow to modify the BOOTPROTO ..." ;;
				N|n)
					echo -e "\nEXIT"
					sleep 1
					echo -e "\033[32m\033[0m" 				
					break
				;;
			esac
			echo -e "\033[32m\033[0m" 				
		;;
	esac	
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
	/etc/init.d/network restart;
	echo -e "\033[32m\n+++++++the IP configuration+++++++\033[1m"
	cat ${IP_CONFIG};
	echo -e "\033[32m\n++++++++++++++++++++++++++++++++++\033[0m"
else
	echo -e "\033[31mThe ${IP_CONFIG} is exists,Please check...\033[0m" 
fi
}
#虚拟机克隆后无法上网的配置函数
function chang_net_rules(){
    NET_RULES_FILES='/tmp/net_rules.txt'
    rm -rf ${NET_RULES_FILES}
    grep ${MAC_ADDR} ${ETH_FILES} >${NET_RULES_FILES}
    sed -i "/NAME/s/eth[0-9]/eth0/g" ${NET_RULES_FILES}
    cat ${NET_RULES_FILES} >${ETH_FILES};
    if [ $? -eq 0 ];then
        echo -e "\033[32mModify the ${ETH_FILES} configuration is successfully...\033[0m"
    else
        echo -e "\033[31mModify the ${ETH_FILES} configuration was failed.\033[0m"
    fi
	cat ${ETH_FILES};
    rm -rf ${NET_RULES_FILES};
}
function chang_hostname(){
echo -e "\033[32mWill modify the hostname...\033[0m"
read -p "Please input hostname: " HOST_NAME
#永久生效
sed -i "/HOSTNAME/s/=.*/=${HOST_NAME}/g" ${HOSTNAME_CONFIG}
#临时生效，立马就能看到结果
hostname ${HOST_NAME};
#修改/etc/hosts
host=`grep "${HOST_NAME}" ${HOSTS_CONFIG}|wc -l`
if [ ${host} -gt 0 ];then
	echo -e "\033[32mThe ${HOSTS_CONFIG} is exists ${HOST_NAME}...\033[1m"
	read -n 1 -p "Continue to modify please input Y|y ,or input N|n : " hosts_ok
    case ${hosts_ok} in
        Y|y) echo "Now modify the hostname..." ;;
        N|n)
	        echo -e "\nExit to modify the hostname..."
            sleep 1
            echo -e "\033[32m\033[0m"
			break
        ;;
    esac
    echo -e "\033[32m\033[0m"
	sed -i "/${HOST_NAME}/d" ${HOSTS_CONFIG}
	echo "iamIPaddress ${HOST_NAME}" >>${HOSTS_CONFIG}        
else
	echo -e "\033[32mNow,will modify the hostname of ${HOSTS_CONFIG}...\033[0m"
	echo "iamIPaddress ${HOST_NAME}" >>${HOSTS_CONFIG}
fi
#if [ "`hostname`" -eq "`echo ${HOSTNAME}`" ];then
	echo -e "\033[32mThe hostname is modify successfully...\n\
Reboot the system entry into force...\033[0m"
#else
#	echo -e "\033[31mThe hostname is modify failed,Please check.\033[0m"
#fi
}
#脚本选择菜单
menu=(
	chang_ip_config
	chang_hostname
	chang_net_rules
	exit_menu
	help_menu
)
PS3="Please select menu will running to do (Need help,Please input: ${#menu[@]} ): "
select i in ${menu[@]}
do
	case $i in
		${menu[0]})
			chang_ip
			if [ "$?" -eq 0 ];then
				echo -e "\033[32mModify the IP configuration is successfully...\033[0m" 
			else
				echo -e "\033[31mPlease check the status of IP configuration...\033[0m" 
			fi
		;;
		${menu[1]}) chang_hostname ;;
		${menu[2]}) chang_net_rules ;;
		${menu[3]}) 
			echo -e "\033[32mPlease reboot the system...\033[1m"
		    read -n 1 -p "Continue to reboot system, Please input Y|y ,or input N|n : " hosts_ok
		    case ${hosts_ok} in
				Y|y) echo "Now restart the system..."; init 6 ;;
		        N|n)
	            echo -e "\033[32m\033[0m"
		        exit ;;
		    esac ;;
		${menu[4]})
			echo -e "\033[32m=========HELP MENU==========\033[0m" 
			
			for ((i=0;i<"${#menu[@]}";i++))
			do
				echo -e "\033[33m `expr $i + 1`) ${menu[i]} \033[0m"
			done
		;;
	esac
done

