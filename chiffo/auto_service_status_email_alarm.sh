#!/bin/bash
#auto service status email alarm,服务启动状态EMAIL报警
#by colink on 2015-05-12
#version v.c.s.0.1

EMAIL='kongzi68@qq.com'
TEMP_EMAIL_FILES='/tmp/temp_email_service_files.txt'
IP_ADDR=`ifconfig eth0|grep "Bcast"|awk -F: '{print $2}'|awk '{print $1}'`

#定义可传递参数的服务状态检测函数
function service_status(){
local $1 2>/dev/null
#这里的grep需要过滤【shell脚本名称的关键词和grep】这个词
STATUS_NUM=`ps -ef |grep "$1" |grep -Ev "grep|alarm"|wc -l`
if [ "${STATUS_NUM}" -eq 0 ];then
	echo -e "\033[31mThe $1 service did not start,Please check...\033[0m"
    #邮件报警内容
    cat >${TEMP_EMAIL_FILES} <<EOF
*********服务状态未启动报警*********

通知类型：服务未启动
主机：${IP_ADDR}
服务：$1
时间：`date`
内容：$1服务未启动，请检查...
EOF
    dos2unix -K ${TEMP_EMAIL_FILES} 2>/dev/null
    mail -s "主机${IP_ADDR}:$1未启动" ${EMAIL} <${TEMP_EMAIL_FILES}
	rm -rf ${TEMP_EMAIL_FILES}
else
	echo -e "\033[32mThe $1 service was started...\033[0m"
fi
}

server_array=( $* )
if [ "${#server_array[@]}" -eq 0 ];then
	echo -e "\033[32mUsage service: mysql httpd\
\nUsage service list: /tmp/service_list.txt\033[0m"
	echo -e "\033[32mYou can create /tmp/service_list.txt like this:\
\nmysql\nhttpd\nnginx\ncacti\nnfs\033[0m"
else
	for ((i=0;i<"${#server_array[@]}";i++))
	do
		if [ -f ${server_array[i]} ];then
			while read line
			do
				SERVER_NAME=`echo ${line}`
				service_status ${SERVER_NAME};
			done < ${server_array[i]}
		else
			service_status ${server_array[i]};
		fi
	done
fi

