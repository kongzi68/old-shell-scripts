#!/bin/bash
# by colin on 2016-08-05
# revision on 2016-08-05
##################################
##脚本功能：
# 通过遍历服务器列表数组，自动远程去执行相应的命令
#
##脚本说明：
# 目前还有一点问题
# 1、通过sudo方式，其>、>>权限需要找到无权限的处理方法。
# 2、添加计划任务* 变成了脚本名称。这个需要转义？
# 3、将继续优化一下，以后就可以用来批量执行一些简单命令了。
#
##更新记录：
#
##################################
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

SSHUSER='windplay'
PROT='22'

SERVER_LIST_ARRARY=(
    01:OSS:iamIPaddress:OSS
    02:Login:iamIPaddress:Login
    03:GSDB1+2_M:iamIPaddress:GSDB1_M
    04:GSDB3+4_M:iamIPaddress:GSDB2_M
    05:GSDB5+6_M:iamIPaddress:GSDB3_M
    10:GSDB_S1_4:iamIPaddress:GSDB_S1_4
    11:GSDB_S5_8:iamIPaddress:GSDB_S5_8
    40:OSS_RECORD_M:iamIPaddress:OSS_RECORD_M
    41:OSS_RECORD_S:iamIPaddress:OSS_RECORD_S
    42:Login_DB_M:iamIPaddress:Login_DB_M
    43:Login_DB_S:iamIPaddress:Login_DB_S
    44:OSS_DB_M:iamIPaddress:OSS_DB_M
    45:OSS_DB_S:iamIPaddress:OSS_DB_S
    46:BACKUP:iamIPaddress:BACKUP
    48:WSDB_S:iamIPaddress:WSDB_S
    53:Test_Server:iamIPaddress:Test_Server
    54:TS_DB:iamIPaddress:TS_DB
)

##
# ssh远程执行命令的函数，$1是被执行命令的服务器IP地址，$2是需要被执行的命令
#
sshExecCommand(){
    local SERVER_IP=$1
    local DO_COMMAND=$2
    ssh -o StrictHostKeyChecking=no -p${PROT} ${SSHUSER}@${SERVER_IP} -i /home/zhangsan/.ssh/3jianhao -t ${DO_COMMAND}
}

##
# 这部分还需要优化
#
for SERVER_INFO in ${SERVER_LIST_ARRARY[@]}
do
    SERVER_IP=$(echo ${SERVER_INFO} | awk -F':' '{print $3}')
    #OLD_TIMEZONE=$(ssh -o StrictHostKeyChecking=no -p${PROT} ${SSHUSER}@${SERVER_IP} -i .ssh/3jianhao "date" | awk '{print $5}')
    OLD_TIMEZONE=$(sshExecCommand "${SERVER_IP}" "sudo date" | awk '{print $5}')
    if [ "${OLD_TIMEZONE}" = "ICT" ];then
        sshExecCommand "${SERVER_IP}" "sudo yum install ntpdate -y && sudo echo '*/30 * * * * /usr/sbin/ntpdate pool.ntp.org >> /var/log/ntpdate_run.log &' >> /var/spool/cron/IamUsername "
        exit
    else
        sshExecCommand "${SERVER_IP}" "sudo cp /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime && sudo yum install ntpdate -y && sudo ntpdate pool.ntp.org"
        [ $? -eq 0 ] && sshExecCommand "${SERVER_IP}" "sudo echo '*/30 * * * * /usr/sbin/ntpdate pool.ntp.org >> /var/log/ntpdate_run.log &' >> /var/spool/cron/IamUsername"
        exit
    fi
done