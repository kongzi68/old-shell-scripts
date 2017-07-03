#!/bin/bash
#auto disk monitoring alarm,磁盘监控报警
#by colink on 2015-05-12
#version v.c.d.0.1 

EMAIL='kongzi68@qq.com'
TEMP_EMAIL_FILES='/tmp/temp_email_files.txt'
TEMP_DISKINFO='/tmp/mon_alarm_diskinfo.txt'
df -Ph |grep "^/dev/" >${TEMP_DISKINFO}
ALARM_VALUE='5'  #警戒线的值
IP_ADDR=`ifconfig eth0|grep "Bcast"|awk -F: '{print $2}'|awk '{print $1}'`

while read line
do
	D_USED=`echo ${line} |awk '{print $5}'`
	D_USED_PERCENT=`echo ${D_USED}|sed "s/%//g"`
	D_TOTAL=`echo ${line} |awk '{print $2}'`
	D_AVAIL=`echo ${line} |awk '{print $4}'`
	D_NAME=`echo ${line} |awk '{print $1"中的"$NF}'`
	if [ "${D_USED_PERCENT}" -gt ${ALARM_VALUE} ];then
		#邮件报警内容
		cat >${TEMP_EMAIL_FILES} <<EOF
*********磁盘使用率超过警戒线报警*********

通知类型：故障

服务：Disk Monitor
主机：${IP_ADDR}
挂载点：${D_NAME}分区
使用率：${D_USED}
总容量：${D_TOTAL};可用容量：${D_AVAIL}

报警时间：`date`
报警内容：使用率超过${ALARM_VALUE}%
EOF
		dos2unix -K ${TEMP_EMAIL_FILES}
		mail -s "主机${IP_ADDR}:${D_NAME}分区报警" ${EMAIL} <${TEMP_EMAIL_FILES}
		rm -rf ${TEMP_EMAIL_FILES} ${TEMP_DISKINFO}
	fi
#	echo " ${D_NAME}    ${D_USED_PERCENT}"
done <${TEMP_DISKINFO}








