#!/bin/bash

# 进程名  
proc_name="taillog_main.py"
proc_dir="/data/server/oss_agent/scripts"
# 日志文件  
reboot_log="/data/server/oss_agent/reboot.log"

num=$(ps -ef | grep $proc_name | grep -vE "grep|$(basename $0)" | wc -l)
if [ $num -eq 0 ];then                                   # 判断进程是否存在  
    cd $proc_dir
    nohup python -u ${proc_name} /data/logs/cba_dsslog /data/logs/taillog_main_run.log &    
    pid=$(ps -ef | grep $proc_name | grep -v grep | awk '{print $2}')
    echo "${pid}, $(date +%F" "%T":"%N)" >>  $reboot_log                   # 将新进程号和重启时间记录  
fi
