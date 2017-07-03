#!/bin/bash

PINGTIME=${1?Please input ping_time.}
IPLIST="/home/colin/ip.txt"
DIRPING="/var/log/ping"

SEND_THREAD_NUM=`cat ${IPLIST}|wc -l`       #设定线程数
tmp_fifofile="/tmp/$$.fifo"      # $$表示进程ID号作为文件名
mkfifo "$tmp_fifofile"       #创建管道文件
exec 6<>"$tmp_fifofile"      #把文件描述符6指向管道文件
rm -f $tmp_fifofile          #删除管道文件
for ((i=0;i<$SEND_THREAD_NUM;i++));do
    echo
done >&6

[ ! -d ${DIRPING} ] && mkdir ${DIRPING}
while read line
do
    read -u6 
    {
        STATIONNAME=`echo "$line" |awk '{print $1}'`
        IPADDR=`echo "$line" |awk '{print $2}'|sed "s/\\r//g"`
        ping -c ${PINGTIME} ${IPADDR} >> "${DIRPING}/${STATIONNAME}_${IPADDR}.log"
        echo >&6
    } &
done < ${IPLIST}
wait 
exec 6>&- 
