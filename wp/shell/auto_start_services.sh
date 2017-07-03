#! /bin/sh  

# 进程名  
proc_name="statisticsadapter_0_0_IOS"
proc_dir="/data/server/statisticsadapterset/statisticsadapter_ios"
# 日志文件  
reboot_log="${proc_dir}/reboot.log"

num=$(ps -ef | grep $proc_name | grep -vE "grep|$(basename $0)" | wc -l)
if [ $num -eq 0 ];then                                   # 判断进程是否存在  
    cd $proc_dir
    ./$proc_name -d                               # 重启进程 
    pid=$(ps -ef | grep $proc_name | grep -v grep | awk '{print $2}')
    echo "${pid}, $(date +%F" "%T":"%N)" >>  $reboot_log                   # 将新进程号和重启时间记录  
fi
