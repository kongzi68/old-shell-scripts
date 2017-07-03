#!/bin/bash
#Check system status
#by colin
#revision on 2015-09-14
#
#功能说明：该脚本用于检测系统状态，包含：ping、负载、内存、磁盘等
#更新说明：
#
#
############################

#sleep 60   #延时60秒运行
scripts_run_log='/var/log/cron_scripts_run.log'
echo -e "\033[32m`date +%F" "%T":"%N` Now, Script: $0 will run...\033[0m" >> ${scripts_run_log}

############################
temp_dir='/tmp/check_system_dir/'
[ -d ${temp_dir} ] || mkdir -p ${temp_dir}

#函数名称：cut_to_check
#函数功能：分析与切割salt工具生成的数据
#使用方法：cut_to_check ${need_to_do_file} check_disk
#其中参数2枚举如下：check_disk、check_load、check_mem、check_ping
cut_to_check(){
    cd ${temp_dir} && {
        check_file=$1
        row_num_list="/tmp/temp_num_list$$.txt"
        cat ${check_file}|grep -n ":$"|awk -F: '{print $1}' > ${row_num_list}
        while_num=`cat ${row_num_list}|wc -l`
    
        for ((i=1;i<=${while_num};i++))
        do            
            m=`sed -n "${i}p" ${row_num_list}`
            n=`sed -n "$(expr ${i} + 1)p" ${row_num_list}`
            #当循环到最后一次时，sed需要截取的内容是从最后一个i值到整个文件需要处理的总行数之间的内容
            system_name=`sed -n "${m}p" ${check_file}|awk -F: '{print $1}'`
            need_do_temp="/tmp/need_do_temp$$.txt"
            if [ ${i} -eq ${while_num} ];then
                sed -n "${m},$(cat ${check_file} | wc -l)p" ${check_file} >${need_do_temp}
            else
                sed -n "${m},$(expr ${n} - 1)p" ${check_file} >${need_do_temp}
            fi
            [ -f ${temp_dir}${system_name} ] || touch ${temp_dir}${system_name}
            case $2 in
                check_disk)
                    temp_disk_info="/tmp/temp_disk_info.txt"
                    `cat ${need_do_temp}|grep -E "${cmd_grep}" |awk "{print ${cmd_awk}}" > ${temp_disk_info}`
                    temp_do=""
                    while read line
                    do
                        temp_do="${temp_do} ${line}"
                    done < ${temp_disk_info}
                    do_done=`echo ${temp_do}|sed 's/ /,/g'`
                ;;
                check_load)
                    do_done=`cat ${need_do_temp}|grep "${cmd_grep}" |sed "s/ //g"|awk -F, "{print ${cmd_awk}}"`
                ;;
                check_mem)
                    do_done1=`cat ${need_do_temp}|grep "${cmd_grep1}" |awk "{print ${cmd_awk1}}"`
                    do_done2=`cat ${need_do_temp}|grep "${cmd_grep2}" |awk "{print ${cmd_awk2}}"`
                    do_done="Mem::${do_done1}:${do_done2}"
                ;;
                check_ping)
                    echo "datatype::server datastr::$(date +%s) servername::${system_name}" > ${temp_dir}${system_name}
                    do_done=`cat ${need_do_temp}|sed -n "2p"|awk '{print "ping::"$1}'`
                ;;
            esac
            echo "${do_done}" >> ${temp_dir}${system_name}
            #echo "-----------------------" >> ${temp_dir}${system_name}
        done
        [ -f ${need_do_temp} ] && rm ${need_do_temp}
        [ -f ${row_num_list} ] && rm ${row_num_list}
    }
    return 0
}

#
need_to_do_file='/tmp/check_info.txt'

#分析ping信息
salt "*" test.ping > ${need_to_do_file}
#调用函数cut_to_check，分析ping信息
cut_to_check ${need_to_do_file} check_ping
[ $? -eq 0 ] && echo -e "\033[32m`date +%F" "%T":"%N` Check: ping done.\033[0m" >> ${scripts_run_log} || {
    echo -e "\033[31m`date +%F" "%T":"%N` Check: ping is failed...\033[0m" >> ${scripts_run_log}
}

#分析系统负载
salt "*" cmd.run "uptime" > ${need_to_do_file}
cmd_grep='load average'
cmd_awk='"load_average::"$5'
#调用函数cut_to_check，分析负载信息
cut_to_check ${need_to_do_file} check_load
[ $? -eq 0 ] && echo -e "\033[32m`date +%F" "%T":"%N` Check: load average info done.\033[0m" >> ${scripts_run_log} || {
    echo -e "\033[31m`date +%F" "%T":"%N` Check: load average is failed...\033[0m" >> ${scripts_run_log}
}

#分析内存信息
salt "*" cmd.run "free -m" > ${need_to_do_file}
cmd_grep1='Mem:'
cmd_grep2='cache:'
cmd_awk1='$2'
cmd_awk2='$4'
#调用函数cut_to_check，分析内存信息
cut_to_check ${need_to_do_file} check_mem
[ $? -eq 0 ] && echo -e "\033[32m`date +%F" "%T":"%N` Check: Mem info done.\033[0m" >> ${scripts_run_log} || {
    echo -e "\033[31m`date +%F" "%T":"%N` Check: Mem info is failed...\033[0m" >> ${scripts_run_log}
}

#分析磁盘信息
salt "*" cmd.run "df -hP" > ${need_to_do_file}
cmd_grep='/$|home|data'
cmd_awk='$NF"::"$2"="$5"="$4'
#调用函数cut_to_check，分析磁盘信息
cut_to_check ${need_to_do_file} check_disk
[ $? -eq 0 ] && echo -e "\033[32m`date +%F" "%T":"%N` Check: disk info done.\033[0m" >> ${scripts_run_log} || {
    echo -e "\033[31m`date +%F" "%T":"%N` Check: disk info is failed...\033[0m" >> ${scripts_run_log}
} 

#
system_info_file='/tmp/system_info_file.txt'
#循环处理生成的每台服务器信息并汇总
[ -d ${temp_dir} ] && cd ${temp_dir} && {
    for i in `find . -type f`
    do
        file_name=`echo $i|awk -F/ '{print $2}'`
        temp_info=""
        while read line
        do
            temp_info="${temp_info} ${line}"
        done < ${file_name}
        echo ${temp_info} >> ${system_info_file}
    done
    #循环处理结束之后，清理临时文件
    rm *
}

#清理产生的临时文件
[ -f ${need_to_do_file} ] && rm ${need_to_do_file}

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



