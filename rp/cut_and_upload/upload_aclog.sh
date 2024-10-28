#!/bin/bash
#Cut and upload aclog
#by colin
#revision on 2015-09-08
########################################
#功能说明：该脚本只能运用于aclog保存在window上的服务器
#
#部署说明：
#脚本计划需要在每个整点的2分钟之后执行：2 * * * * /IamUsername/upload_aclog.sh
#因为win_aclog服务器上的日志保存工具是在每个整点时运行并生成日志文件，因此需要错开这个时间
#
#更新说明：
#2015年9月30日，修正获取ftp返回状态信息的方式，并修改了判断依据
#
########################################
sleep 20    #延时20秒运行
scripts_run_log='/var/log/cron_scripts_run.log'
echo "`date +%F" "%T":"%N` Script: $0 will run..." >> ${scripts_run_log}

#############################
#define the ftp client
lcd_dir='/mnt'
cd_dir="/aclog/sd/qdn"
log_type="aclog"
win_ip='iamIPaddress'       #保存aclog日志的win服务器地址
win_dir='oldlog'
#############################

tmp_t=`date +%k`
T=`echo ${tmp_t} |sed 's/ //g'`
tmp_last_t=`date -d "1 hour ago" +%k`
LAST_T=`echo ${tmp_last_t} |sed 's/ //g'`

day_time=`date +%Y-%m-%d`
last_day_time=`date -d "yesterday" +%Y-%m-%d`
#last_hour_time=`date -d "1 hour ago" +%Y-%m-%d-%H`
last_hour_time=`date +%Y-%m-%d-%H`

mnt_dir="${lcd_dir}/${log_type}"
log_name="${mnt_dir}${last_hour_time}.txt"

#检测win服务器是否在线
win_status=`ping -c 4 ${win_ip} |grep "packet loss" |awk -F, '{print $(NF-1)}'|awk '{print $1}'|sed 's/%//g'`
#若ping 4次的话，丢包率大于50，就算失败
if [ ${win_status} -gt 50 ];then
    echo "`date +%F" "%T":"%N` Ping: win_aclog server is ${win_status}% packet loss, Please check..." >> ${scripts_run_log}
    echo "`date +%F" "%T":"%N` Script: $0 run done." >> ${scripts_run_log}
    exit
else
    check_mnt=`df -hP|grep "oldlog" |wc -l`
    if [ ${check_mnt} -le 0 ];then
        mount -t cifs -o username=administrator,password=rockHIPPO@321 //${win_ip}/${win_dir} ${lcd_dir} && {
        echo "`date +%F" "%T":"%N` Mount: win_aclog server was successfully." >> ${scripts_run_log}
        } || echo "`date +%F" "%T":"%N` Mount: win_aclog server was failed, Please check..." >> ${scripts_run_log}
    else
        echo "`date +%F" "%T":"%N` Do not need to mount." >> ${scripts_run_log}
    fi    
fi

#把每小时的日志追加到整天的日志记录中
if [ "${T}" -eq 0 ];then
    temp_check_log=`ls -l ${mnt_dir}${last_day_time}.txt |awk '{print $5}'`
    cat ${log_name} >> ${mnt_dir}${last_day_time}.txt
    [ $? -eq 0 ] || cat ${log_name} >> ${mnt_dir}${last_day_time}.txt
    check_log=`ls -l ${mnt_dir}${last_day_time}.txt |awk '{print $5}'`
else
    #每整天的日志文件是在1点钟的时候创建的，即1点时刻文件大小为0，先有文件才能用ls去检测
    [ -f ${mnt_dir}${day_time}.txt ] || touch ${mnt_dir}${day_time}.txt
    temp_check_log=`ls -l ${mnt_dir}${day_time}.txt |awk '{print $5}'`
    cat ${log_name} >> ${mnt_dir}${day_time}.txt
    [ $? -eq 0 ] || cat ${log_name} >> ${mnt_dir}${day_time}.txt
    check_log=`ls -l ${mnt_dir}${day_time}.txt |awk '{print $5}'`
fi

echo -e "\033[32m`date +%F" "%T":"%N` CHECK: check_log=${check_log},temp_check_log=${temp_check_log}...\033[0m" >> ${scripts_run_log}
#clean up the old log file
[ -s ${log_name} ] && {
    if [ "${check_log}" -gt "${temp_check_log}" ];then
        [ $? -eq 0 ] && echo "`date +%F" "%T":"%N` The ${log_type}_log has been successfully backed up..." >> ${scripts_run_log} 
    else
        echo "`date +%F" "%T":"%N` Backup the ${log_type}_log was failed, Please check..." >> ${scripts_run_log}
        exit
    fi
} || echo -e "\033[31m`date +%F" "%T":"%N` LOG: ${log_name} is null.\033[0m" >> ${scripts_run_log}

###########################################################
#FTP循环上传代码段于2015-07-27修改
###########################################################
ftp_err_dir="/tmp/ftp_err/"
[ -d ${ftp_err_dir} ] || mkdir -p ${ftp_err_dir}
ftp_err_log="${ftp_err_dir}ftp_temp_${log_type}_err$$.log"

put_log_day_name="${log_type}${last_day_time}.txt"
put_log_hour_name="${log_type}${last_hour_time}.txt"

#FTP自动化上传函数
function send_log() {
    ftp -ivn iamIPaddress 21 >${ftp_err_log} << _EOF_
    user upload chriscao
    passive
    bin
    lcd ${lcd_dir}
    cd  ${cd_dir}
    put $1
    bye
_EOF_
#统计前面FTP运行输出的错误日志记录行数
log_count=`grep "^226" ${ftp_err_log}|wc -l`
[ ${log_count} -eq 1 ] && ftp_stat=0 || ftp_stat=1
if [ ${ftp_stat} -eq 0 ];then
    echo "`date +%F" "%T":"%N` Send: $1 to ftp_server was successfully." >> ${scripts_run_log}
    return 0
else
    echo "`date +%F" "%T":"%N` Send: $1 more than $x time." >> ${scripts_run_log}
    sleep 120
    return 1
fi
}

#根据计划任务，脚本每运行一次就执行一次
[ -f "${lcd_dir}/${put_log_hour_name}" ] && {
x=1
i=1
until [ "$i" -eq 0 ];do
    [ $x -gt 3 ] && {
        echo "`date +%F" "%T":"%N` Send: ${put_log_hour_name} to ftp_server was failed, Please check..." >> ${scripts_run_log}
        break
    }
    send_log "${put_log_hour_name}"
    i=`echo $?`
    x=`expr $x + 1`
done
}

#零点的时候，发送上一天的完整日志
[ "${T}" -eq 0 ] && [ -f "${lcd_dir}/${put_log_day_name}" ] && {
x=1
i=1
until [ "$i" -eq 0 ];do
    [ $x -gt 3 ] && {
        echo "`date +%F" "%T":"%N` Send: ${put_log_day_name} to ftp_server was failed, Please check..." >> ${scripts_run_log}
        break
    }
    send_log "${put_log_day_name}"
    i=`echo $?`
    x=`expr $x + 1`
done
}

#删除FTP产生的临时错误日志文件
[ -f ${ftp_err_log} ] && rm ${ftp_err_log}

#清理超过90天的备份日志
[ -d ${lcd_dir} ] && cd ${lcd_dir} && {
    for filename in `find . -type f -ctime +90 | awk -F/ '{print $2}'`
    do
        rm  ${filename}
        [ $? -eq 0 ] && echo "`date +%F" "%T":"%N` Clear: ${lcd_dir}/${filename}.." >> ${scripts_run_log}
    done
}

#清理脚本运行日志记录/var/log/cron_scripts_run.log
TEMP_WC=`cat ${scripts_run_log} |wc -l`
if [ "${TEMP_WC}" -gt 10000 ];then
    sed -i "1,5000d" ${scripts_run_log}
    echo "`date +%F" "%T":"%N` Clean up the ${scripts_run_log}..." >> ${scripts_run_log}
    echo "`date +%F" "%T":"%N` Script: $0 run done." >> ${scripts_run_log}
else
    echo "`date +%F" "%T":"%N` Script: $0 run done." >> ${scripts_run_log}
    exit
fi
