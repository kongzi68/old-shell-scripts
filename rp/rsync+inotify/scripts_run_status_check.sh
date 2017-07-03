#!/bin/bash
#
# 检查auto_inotify.sh是否运行，未运行就启动

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SCRIPTS_NAME=(
	/root/train_service/auto_inotify.sh
	/root/train_service/download_log_to_chengdu_tongji.sh
)
for i in ${SCRIPTS_NAME[@]}
do
	PS_NUM=$(ps -ef | grep -v "grep" | grep "$(basename $i )" | wc -l )
	[ "${PS_NUM}" -ge 1 ] || nohup $i &
done
