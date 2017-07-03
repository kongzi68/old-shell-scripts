#!/bin/bash
#
# 检查auto_inotify.sh是否运行，未运行就启动
#

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SCRIPTS_NAME='/root/train_service/auto_inotify.sh'

PS_NUM=$(ps -ef | grep -v "grep" | grep "$(basename ${SCRIPTS_NAME})" | wc -l )
if [ "${PS_NUM}" -ge 1 ];then
    exit
else
    nohup ${SCRIPTS_NAME} &
fi

