#!/bin/bash
#
############################################
#       检测AP在线状态及报警
#
#2015-11-03 by colin
#version:1.4
#功能描述：
#1、通过ping返回的状态进行判断设备是否在线；
#2、模拟多线程
#3、上传检测结果
#
#使用方法：
#添加计划任务如下，每10分钟检测一次
#  */5 * * * * /root/check_ap_status.sh  >>/var/log/check_ap_script_run.log  2>&1 &
#更新说明:
#9月7日，增加多线程功能，降低脚本运行总时间
#9月16日，脚本结构大调整，转化成函数，具体看函数功能介绍
#9月24日，把检查的信息，上传到阿里云服务器
#
############################################

#sleep 20   #延时20秒运行
scripts_run_log='/var/log/check_ap_script_run.log'
echo "`date +%F" "%T":"%N` Script: $0 will running..." >> ${scripts_run_log}

station='JN'

check_ping(){
    SEND_THREAD_NUM=15  
    tmp_fifofile="/tmp/$$.fifo"  
    mkfifo "$tmp_fifofile"  
    exec 6<>"$tmp_fifofile" 
    rm -f $tmp_fifofile  
    for ((i=0;i<$SEND_THREAD_NUM;i++));do
        echo
    done >&6
    for ((i=$1;i<=$2;i++))
    do
        read -u6  
        {
            if [[ "$4" = "-i" ]];then
                ip_values=$5$i  
            else
                ip_values=$4
            fi
            ap_status=`ping -c 4 ${ip_values} |grep "packet loss" |awk -F, '{print $(NF-1)}'|awk '{print $1}'|sed 's/%//g'`
            check_info="${station} $3 ${ip_values} ${ap_status}"  
            echo "${check_info}"  >> ${scripts_run_log}
            curl -F "datatype=networkdev" -F "datastr=$(date +%s) ${check_info}" http://monitor.hoobanr.com/monitor.php 
            echo >&6  
        } & 
    done
    wait  
    exec 6>&- 
    return 0
}

#调用函数check_ping，检测AC或者是有非连续固定IP的设备状态
#这里可添加多个需要检测的固定ip地址
#CO:'192.168.102.254'
IP_ADDRS=(
    
)
for i in ${IP_ADDRS[@]}
do
    IPADDRS=`echo "${i}" |awk -F: '{print $2}'`
    DEVICENAME=`echo "${i}" |awk -F: '{print $1}'`
    check_ping 1 1 ${DEVICENAME} ${IPADDRS}
done

#调用函数check_ping，检测SW状态
for_a='1'
for_b='8'
ap_ipaddr='192.168.102.'
check_ping ${for_a} ${for_b} SW -i ${ap_ipaddr}

#调用函数check_ping，检测AP状态
for_a='11'
for_b='109'
ap_ipaddr='192.168.102.'
check_ping ${for_a} ${for_b} AP -i ${ap_ipaddr}

[ -f ${TEMP_EMAIL_FILES} ] && rm -rf ${TEMP_EMAIL_FILES}

TEMP_WC=`cat ${scripts_run_log} |wc -l`
if [ "${TEMP_WC}" -gt 10000 ];then
    sed -i "1,5000d" ${scripts_run_log}
    echo "`date +%F" "%T":"%N` Clean up the ${scripts_run_log}..." >> ${scripts_run_log}
    echo "`date +%F" "%T":"%N` Script: $0 done." >> ${scripts_run_log}
else
    echo "`date +%F" "%T":"%N` Script: $0 done." >> ${scripts_run_log}
    exit
fi


