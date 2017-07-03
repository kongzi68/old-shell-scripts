#!/bin/bash
#
############################################
#       创建普通用户和配置SUDO
#
#2015-08-20 by colin
#version:1.0
#使用方法：./create_user_and_set_sudoer.sh
#
#其他：
############################################

#用户数组，格式如下，用户名::密码，这里是两个英文冒号
USER_LIST=(
	testx::123456
	testy::testz@123456
)

TEMPUSERLIST='/tmp/temp_user_list.txt'
#函数功能：创建用户、配置sudo、修改密码
function addUser(){
	USER=`echo "$1" |awk -F"::" '{print $1}'`
	PASSWORD=`echo "$1" |awk -F"::" '{print $2}'`
	useradd -m -s /bin/bash ${USER}
	[ $? -eq 0 ] && echo -e "\033[32m创建用户：${USER}成功。\033[0m" || {
		echo -e "\033[31m创建用户：${USER}失败，请检查。\033[0m"
		exit
	}
	echo "${USER}  ALL=(ALL)  ALL" >> /etc/sudoers
	[ $? -eq 0 ] && echo -e "\033[32m给用户：${USER}成功配置权限。\033[0m" || {
		echo -e "\033[31m给用户：${USER}配置权限失败，请检查。\033[0m"
		exit
	}
	echo "${USER}:${PASSWORD}" |chpasswd
	[ $? -eq 0 ] && echo -e "\033[32m用户：${USER}的密码已成功修改。\033[0m" || {
		echo -e "\033[31m用户：${USER}的密码修改失败，请检查。\033[0m"
		exit
	}
	echo "用户：${USER}；密码：${PASSWORD}" >> ${TEMPUSERLIST}
	return 0
}

#循环数组，调用函数addUser
echo -e "\033[32m=========添加用户脚本正在运行=========\033[0m"
for i in ${USER_LIST[@]}
do
	addUser $i
done

[ -f ${TEMPUSERLIST} ] && {
	echo -e "\033[32m\n----------创建的用户列表如下----------\033[1m"
	cat ${TEMPUSERLIST}
	rm ${TEMPUSERLIST}
	echo -e "\033[32m--------------------------------------\n$0 done.\n\033[0m"
}

