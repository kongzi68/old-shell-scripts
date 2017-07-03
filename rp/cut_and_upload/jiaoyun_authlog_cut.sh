#!/bin/bash
#Cut and upload jyauthlog
#by colin
#revision on 2015-09-14
#
#功能说明：该脚本运用于jyauthlog
#更新说明：
#
#用于切割jiaoyun_auth_access.log，每天切割备份一次，暂用
#
############################

#sleep 60   #延时60秒运行
scripts_run_log='/var/log/cron_scripts_run.log'
echo -e "\033[32m`date +%F" "%T":"%N` Now, The script $0 will run...\033[0m" >> ${scripts_run_log}

############################
server_name=`hostname`          #部署的时候需要修改的变量
#server_name="dqdweb"            #部署的时候需要修改的变量
logs_path="/data/www/logs/"
back_logs_path="/data/www/logbackup/qdjy_authlog/"       #部署的时候需要修改的变量
log_name="jiaoyun_auth_access"
nginx_pid_path="/var/run/nginx.pid"
log_type="authlog"

#define the ftp client
lcd_dir="${back_logs_path}"
#cd_dir="/jyauthlog/qdjy/"         #部署的时候需要修改的变量
############################

nginx_pid=`cat ${nginx_pid_path}`
T=`echo $(date +%k)|sed 's/ //g'`
last_day_time=`date -d "1 hour ago" +%H`
#last_hour_time=`date -d "1 hour ago" +%Y-%m-%d-%H`
#这里临时修改变量取值，暂用
last_day_time=`date -d "yesterday" +%Y-%m-%d`
#last_week_time=`date -d "yesterday" +%w`

#创建备份日志存储文件夹
[ -d ${back_logs_path} ] || mkdir -p ${back_logs_path}
#每小时切割与备份nginx生成的日志
tar_log_day_name="${last_day_time}.${server_name}.jyauthlog.tar.gz"
#先判断这个文件是否存在，不存在才执行后面的命令
cd ${back_logs_path} && [ -f ${tar_log_day_name} ] || {
    [ -f ${logs_path}${log_name}.log ] && mv ${logs_path}${log_name}.log ${log_name}_${last_day_time}.log || {
        echo -e "\033[31m`date +%F" "%T":"%N` The ${logs_path}${log_name}.log is not exist...\033[0m" >> ${scripts_run_log}
        /usr/sbin/service nginx restart
        if [ $? -eq 0 ];then
            echo -e "\033[32m`date +%F" "%T":"%N` Restart nginx is done.\033[0m" >> ${scripts_run_log}
        else
            echo -e "\033[31m`date +%F" "%T":"%N` Restart nginx is failed, Please check...\033[0m" >> ${scripts_run_log}
        fi
        /usr/sbin/service php5-fpm restart
        if [ $? -eq 0 ];then
            echo -e "\033[32m`date +%F" "%T":"%N` Restart php5-fpm is done.\033[0m" >> ${scripts_run_log}
        else
            echo -e "\033[31m`date +%F" "%T":"%N` Restart php5-fpm is failed, Please check...\033[0m" >> ${scripts_run_log}
        fi
        exit
    }
    #增加日志内容是否为空的判断
    [ -f ${log_name}_${last_day_time}.log ] && {
        #切割日志
        kill -USR1 ${nginx_pid}
        # [ $? -eq 0 ] && echo -e "\033[32m`date +%F" "%T":"%N` Create: new ${logs_path}${log_name}.log is successfully.\033[0m" >> ${scripts_run_log} || {
            # echo -e "\033[32m`date +%F" "%T":"%N` Create: new ${logs_path}${log_name}.log was failed, Please check...\033[0m" >> ${scripts_run_log}
        # }            
    } || echo -e "\033[31m`date +%F" "%T":"%N` LOG: ${log_name}_${last_day_time}.log is not exist...\033[0m" >> ${scripts_run_log}
    #打包日志    
    tar -zcf ${tar_log_day_name} --remove-files ${log_name}_${last_day_time}.log 
    if [ $? -eq 0 ] && [ -f ${tar_log_day_name} ];then
        echo -e "\033[32m`date +%F" "%T":"%N` Tar: ${tar_log_day_name} is successfully .\033[0m" >> ${scripts_run_log}
    else
        echo -e "\033[31m`date +%F" "%T":"%N` Tar: ${tar_log_day_name} was failed, Please check...\033[0m" >> ${scripts_run_log}
        exit
    fi
}

#清理超过90天的备份日志
[ -d ${lcd_dir} ] && cd ${lcd_dir} && {
    for filename in `find . -type f -ctime +90 | awk -F/ '{print $2}'`
    do
        rm  ${filename}
        [ $? -eq 0 ] && echo -e "\033[32m`date +%F" "%T":"%N` Clear: ${lcd_dir}${filename}...\033[0m" >> ${scripts_run_log}
    done
}

#清理脚本运行日志记录/var/log/cron_scripts_run.log
TEMP_WC=`cat ${scripts_run_log} |wc -l`
if [ "${TEMP_WC}" -gt 10000 ];then
    sed -i "1,5000d" ${scripts_run_log}
    echo -e "\033[32m`date +%F" "%T":"%N` Clean up the ${scripts_run_log}...\033[0m" >> ${scripts_run_log}
    echo -e "\033[32m`date +%F" "%T":"%N` The script $0 run done.\033[0m" >> ${scripts_run_log}
else
    echo -e "\033[32m`date +%F" "%T":"%N` The script $0 run done.\033[0m" >> ${scripts_run_log}
    exit
fi


