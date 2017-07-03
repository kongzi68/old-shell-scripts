#!/bin/bash
#auto ssh exec command
#by colink on 2015-05-11
#versions v.c.1.0.1

#tmp_test=/tmp/ssh_command.txt
#检测ipaddr列表
IP_LIST=/tmp/ipaddr_list.txt
function ipaddr_list_check() {
if [ ! -f ${IP_LIST} ];then
	echo -e "\033[31mPlease create ${IP_LIST}\
\ne.g.: echo '192.168.2.231  root  /tmp/' >>/tmp/ipaddr_list.txt\033[0m"
	echo -e "\033[33mUsage:ipaddr   user   dir\n192.168.2.230  \
root  /tmp/\n192.168.2.231  root  /tmp/\033[0m"
	exit
fi
}
#ssh远程执行命令函数
function ssh_exec_command() {
echo -e "\033[32mUsage command:\ne.g.:  df -h \
\ne.g.:  /bin/bash /tmp/shell_scripts.sh\033[1m"
read -p "Please input need to exec command: " command
echo -e "\033[32m----------------------------------------\033[0m"
count=`cat ${IP_LIST} |wc -l`
for ((i=1;i<=${count};i++))
do
	USER=`sed -n "${i}p" ${IP_LIST} | awk '{print $2}'`
	IPADDR=`sed -n "${i}p" ${IP_LIST} | awk '{print $1}'`
	ssh -q -l ${USER} ${IPADDR} ${command}
    if [ $? -eq 0 ];then
	    echo -e "\033[32m----------------------------------------\033[0m"
        echo -e "\033[32mSSH exec command ${command} to ${IPADDR} was successfully...\033[0m"
    else
		echo -e "\033[32m----------------------------------------\033[0m"
        echo -e "\033[31mSSH exec command ${command} to ${IPADDR} was failed...\033[0m"
    fi
done
}

#从本机拷贝文件到远程主机
function scp_files() {
echo -e "\033[32mUsage:\ne.g.: /root/test.txt\033[1m"
read -p "Please input need to copy file: " -a files
for ((i=0;i<${#files[@]};i++))
do
	#当输入的既不是文件又不是文件夹的时候，要求重新输入
	while [ ! -f ${files[i]} -a ! -d ${files[i]} ];do
		echo -e "\033[31mThe ${files[i]} is't exist,Please input again...\033[0m"
		read -p "Please input again need to copy file: " -a files
	done
done
echo -e "\033[32m----------------------------------------\033[0m"
while read line
do
    USER=`echo "${line}"|awk '{print $2}'`
    IPADDR=`echo "${line}"|awk '{print $1}'`
	TO_DIR=`echo "${line}"|awk '{print $3}'`
    scp -r ${files[@]} ${USER}@${IPADDR}:${TO_DIR}
    if [ $? -eq 0 ];then
		echo -e "\033[32m----------------------------------------\033[0m"
        echo -e "\033[32mSCP ${files[@]} to ${IPADDR}:${TO_DIR} was successfully...\033[0m"
    else
		echo -e "\033[32m----------------------------------------\033[0m"
        echo -e "\033[31mSCP ${files[@]} to ${IPADDR}:${TO_DIR} was failed...\033[0m"
    fi
done <${IP_LIST}
}
#脚本选择菜单
menu=(
	ipaddr_list_check
	scp_files
	ssh_exec_command
	exit_menu
	help_menu
)
PS3="Please select menu will running to do (Need help,Please input: 5 ): "
select i in ${menu[@]}
do
    case $i in
        ${menu[0]}) ${menu[0]} ;;
        ${menu[1]}) ${menu[1]} ;;
        ${menu[2]}) ${menu[2]} ;;
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
