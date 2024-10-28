#!/bin/bash
# send_log.sh
# by colin on 2017-01-19
# revision on 2017-02-07
##################################
##脚本功能：
# 打包传送官网web1上的/data/www/osslog内的日志文件到其它机器
#
##脚本说明：
# 计划任务,建议定时在凌晨5~10分左右
# #send /data/www/osslog's log to iamIPaddress(write_oss)
# 5 0 * * * /data/scripts/send_log.sh >> /var/log/cron_scripts_run.log 2>&1
#
##功能要求：
# 日志单独打包，分游戏ID存放
# scp传送
# 传送失败就间隔30s重传3次，依然失败的第二次运行时重传
# 错时补传

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/cron_scripts_run.log'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoGoodLog "Now, Script: `basename $0` run."
# 定义常量
RUNLOG_MAX_NUM=100000
RUNLOG_MAX_DELNUM=5000
SEND_MAX_TIME=3
SEND_WHILE_SLEEP_TIME=30

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`cat ${CLEANLOGFILE} |wc -l`
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && {
        sed -i "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE} && echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    echoGoodLog "Script: `basename $0` run done."
    exit
}

tarLogFile(){
    TARTONAME=${1?"Usage: $FUNCNAME tar_file_name need_tar_file_name"}
    FROMLOG=$2
    tar -czf ${TARTONAME} --remove-files ${FROMLOG}
    if [ -e ${TARTONAME} ];then
        echoGoodLog "Tar: ${TARTONAME} is successfully."
    else
        echoBadLog "Tar: ${TARTONAME} was failed, Please check..."
    fi
}

# 日志发送函数
TEMP_SENDLOG_RECORD='/var/log/.temp_sendlog_record.txt'
T_TEMP_SENDLOG_RECORD='/var/log/temp_sendlog_record.txt'
sendLog(){
    LOGNAME=$1
    DIR=$2
    for ((i=1;i<=${SEND_MAX_TIME};i++))
    do
        scp -i /IamUsername/.ssh/id_rsa ${LOGNAME} IamUsername@iamIPaddress:${DIR}
        if [ $? -eq 0 ];then
            echoGoodLog "Send log: ${LOGNAME} is successfully."
            return 0
        else
            echoBadLog "Send log ${i} time: ${LOGNAME} was failed, Please check..."
            sleep ${SEND_WHILE_SLEEP_TIME}
        fi
    done
    if [ ${i} -eq ${SEND_MAX_TIME} ];then
        echo "${LOGNAME}::${DIR}" >> ${T_TEMP_SENDLOG_RECORD}
        return 1
    fi
}

TODAY=$(date +%Y-%m-%d)
# ./log-1003-1-info-2017-02-07.log
# 排除当天的日志文件，只传昨天及以前的所有日志文件
# so,这样就不会漏传以前的日志咯
# 2017-02-07增加变量：DEVID,根据设备类型，创建分目录，具体见变量DIR变化
cd /data/www/osslog/ && {
    for ITEM in $(find . -maxdepth 1 -name "log-*-*-*.log");do
        LOGDATE=$(echo ${ITEM} |grep -oE "[0-9]{4}(-[0-9]{2}){2}")
        if [ ${LOGDATE} = ${TODAY} ];then
            continue
        fi
        LOGNAME="$(echo ${ITEM} |awk -F[./] '{print $3}').tar.gz"
        GAMEID=$(echo ${ITEM} |awk -F[/-] '{print $3}')
        DEVID=$(echo ${ITEM} |awk -F[/-] '{print $4}')
        DIR="/data/funnel/${GAMEID}/${DEVID}"
        tarLogFile ${LOGNAME} ${ITEM}
        ssh -tt -i /IamUsername/.ssh/id_rsa IamUsername@iamIPaddress <<-EOF
            [ ! -d ${DIR} ] && mkdir -p ${DIR}
            exit
EOF
        [ -f ${LOGNAME} ] && sendLog ${LOGNAME} ${DIR}
    done
    # 删除30天以前的日志打包文件
    find . -maxdepth 1 -ctime +30 -name "*.tar.gz" -delete
}

# 重传上次运行传送失败的日志文件
[ -f ${TEMP_SENDLOG_RECORD} ] && {
    while read line
    do
        LOGNAME=$(echo ${line} |awk -F"::" '{print $1}')
        DIR=$(echo ${line} |awk -F"::" '{print $2}')
        [ -f ${LOGNAME} ] && sendLog ${LOGNAME} ${DIR}
    done < ${TEMP_SENDLOG_RECORD}
    rm -f ${TEMP_SENDLOG_RECORD}
}
[ -f ${T_TEMP_SENDLOG_RECORD} ] && mv ${T_TEMP_SENDLOG_RECORD} ${TEMP_SENDLOG_RECORD}

cleanRunLog ${RUN_LOG}
