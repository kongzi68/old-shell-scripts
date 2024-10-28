#!/bin/bash
# Cut and upload nginxlog
# by colin
# revision on 2016-02-22
########################################
# 功能说明：该脚本运用于切割与上传nginxlog
#
# 更新说明：
#
########################################
#sleep 60   #延时60秒运行
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/cron_scripts_run.log'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

echoGoodLog ()
{
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog ()
{
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoGoodLog "Now, Script: `basename $0` run."
RUNLOG_MAX_NUM=100000
RUNLOG_MAX_DELNUM=5000
SEND_MAX_TIME=6
SEND_WHILE_SLEEP_TIME=30
BACK_SAVE_MAX_DAY=180       # 日志本地保存天数 #
LOG_CUT_MIN=60   # 日志文件30分钟切割一次 #

cleanRunLog ()
{
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=$( wc -l < ${CLEANLOGFILE} )
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && {
        sed -i "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE} && echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    echoGoodLog "Script: `basename $0` run done."
    exit
}

SERVER_NAME=${1?Usage: $0 jnweb1 /nginxlog/sd/jn/} 
CD_DIR=$2
LOGS_PATH="/data/store/logs/www/"
LOG_NAME="m_wonaonao_access"
LOG_TYPE="nginx"
LOG_TYPEB="nginx"
LCD_DIR="/data/store/logs/backup/"
STATION=`echo $(hostname) |awk -F- '{print $3}'|tr [A-Z] [a-z]`
########################################
##
# define the ftp server
#
FTPSERVER='iamIPaddress'
FTPUSER='upload'
FTPPASSWD='thisispassword'
SSHPORT='220'
########################################

NGINX_PID=`cat /var/run/nginx.pid`
T=`echo $(date +%k)|sed 's/ //g'`
LAST_HOUR_TIME=`date +%Y-%m-%d-%H`
FILENUM=`expr $(date +%M|sed 's/^0//g') / ${LOG_CUT_MIN}`
RECORD_LOG_VALUE="${FILENUM}"
[ "${FILENUM}" -eq 0 ] && {
    FILENUM=`expr 60 / ${LOG_CUT_MIN}`
    LAST_HOUR_TIME=`date -d "1 hour ago" +%Y-%m-%d-%H`
}
LAST_T_TIME=`date -d "1 hour ago" +%H`
[ "${RECORD_LOG_VALUE}" -gt 0 ] && LAST_T_TIME=`date +%H`
LAST_DATE_TIME=`date -d "yesterday" +%Y-%m-%d`

restartNginx ()
{
    /usr/sbin/service nginx restart && echoGoodLog "Restart nginx is done." || {
        echoBadLog "Restart nginx is failed, Please check..."
    }
}

restartPHP(){
    ##
    # apt-get安装与源码安装的启动脚本名称不一样
    #
    /usr/sbin/service php5-fpm restart || /usr/sbin/service php-fpm restart
    if [ $? -eq 0 ];then
        echoGoodLog "Restart php5-fpm is done."
    else
        echoBadLog "Restart php5-fpm is failed, Please check..."
    fi
}

##
# 为兼容旧版本，当60分钟切割一次时，就和之前旧版本文件名一样咯
#
if [ ${LOG_CUT_MIN} -eq 60 ];then
    TAR_LOG_HOUR_NAME="${LAST_HOUR_TIME}.${SERVER_NAME}.nginxlog.tar.gz"
else
    TAR_LOG_HOUR_NAME="${LAST_HOUR_TIME}-${FILENUM}.${SERVER_NAME}.nginxlog.tar.gz"
fi

cd ${LCD_DIR} && [ ! -e ${TAR_LOG_HOUR_NAME} ] && {
    ##
    # 备份m_wonaonao_access日志
    #
    [ -e ${LOGS_PATH}${LOG_NAME}.log ] && mv ${LOGS_PATH}${LOG_NAME}.log ${LOG_NAME}_${LAST_T_TIME}.log || {
        echoBadLog "Log: ${LOGS_PATH}${LOG_NAME}.log is not exist..."
        restartNginx
        restartPHP
    }
    [ -e ${LOG_NAME}_${LAST_T_TIME}.log -a -s ${LOG_NAME}_${LAST_T_TIME}.log ] && {
        kill -USR1 ${NGINX_PID}
        cat ${LOG_NAME}_${LAST_T_TIME}.log >> ${LOG_NAME}.log || cat ${LOG_NAME}_${LAST_T_TIME}.log >> ${LOG_NAME}.log
        check_log=`stat ${LOG_NAME}.log |grep "Modify:"|awk '{print $3}'|awk -F: '{print $1}' |sed 's/^0//g'`
        if [ "${check_log}" -eq "${T}" ];then
            echoGoodLog "Log: ${LOG_TYPE}_log is cut successfully..."
        else
            echoBadLog "Cut: ${LOG_TYPE}_log was failed, Please check..."
        fi
    } || echoBadLog "Log: ${LOG_NAME}_${LAST_T_TIME}.log is null."
    ##
    # 备份m_wonaonao_record日志，打包
    #
    [ -e ${LOGS_PATH}m_wonaonao_record_${LAST_T_TIME}.log ] && {
        if [ ${RECORD_LOG_VALUE} -gt 0 ];then
            cp -a ${LOGS_PATH}m_wonaonao_record_${LAST_T_TIME}.log  . 
        else
            mv ${LOGS_PATH}m_wonaonao_record_${LAST_T_TIME}.log  . 
        fi
        tar -zcf ${TAR_LOG_HOUR_NAME} ${LOG_NAME}_${LAST_T_TIME}.log m_wonaonao_record_${LAST_T_TIME}.log
    } || tar -zcf ${TAR_LOG_HOUR_NAME} ${LOG_NAME}_${LAST_T_TIME}.log
    if [ -e ${TAR_LOG_HOUR_NAME} ];then
        echoGoodLog "Tar: ${TAR_LOG_HOUR_NAME} is successfully in every hour..."
    else
        echoBadLog "Tar: ${LOG_TYPE}_log of every hour was failed, Please check..."
    fi
}

TAR_LOG_DAY_NAME="${LAST_DATE_TIME}.${SERVER_NAME}.nginxlog.tar.gz"

tarDayLog ()
{
    TAR_DAY_LOG=$1
    cd ${LCD_DIR} && [ -e ${TAR_DAY_LOG} ] || {
    tar -zcPf ${TAR_DAY_LOG} --remove-files ${LOG_NAME}.log m_wonaonao_record_*.log
    if [ -e ${TAR_DAY_LOG} ];then
        echoGoodLog "Tar: ${TAR_DAY_LOG} is successfully in every day..."
    else
        echoBadLog "Tar: ${TAR_DAY_LOG} of the whole day was failed, Please check..."
    fi
    }
}

##
# 打包每天完整的日志
#
[ "${T}" -eq 0 -a "${RECORD_LOG_VALUE}" -eq 0 ] && tarDayLog ${TAR_LOG_DAY_NAME}

FTP_LOG_DIR="/tmp/ftp_err"
[ -d ${FTP_LOG_DIR} ] || mkdir -p ${FTP_LOG_DIR}
FTP_ERROR_LOG="${FTP_LOG_DIR}/ftp_temp_${LOG_TYPE}_err$$.log"

sendLog ()
{
    SENDLOGFILE=$1
    ftp -ivn ${FTPSERVER} 21 >${FTP_ERROR_LOG} << _EOF_
user ${FTPUSER} ${FTPPASSWD}
passive
bin
lcd ${LCD_DIR}
cd  ${CD_DIR}
put ${SENDLOGFILE}
bye
_EOF_
    ##
    # 统计前面FTP运行输出的错误日志记录行数
    #
    LOG_COUNT=`grep -w "^226" ${FTP_ERROR_LOG}|wc -l`
    if [ "${LOG_COUNT}" -eq 1 ];then
        echoGoodLog "Send: ${SENDLOGFILE} to ftp_server was successfully."
        TEMP_SEND_STATUS=0
        return 0
    else
        echoBadLog "Send: ${SENDLOGFILE} more than $x time."
        TEMP_SEND_STATUS=1
        sleep ${SEND_WHILE_SLEEP_TIME}
        return 1
    fi
}

REUPLOADLIST="/var/log/reupload_list_${LOG_TYPEB}_${STATION}.log"
TEMP_REUPLOADLIST="/var/log/temp_reupload_list_${LOG_TYPEB}_${STATION}.log"
[ -f ${TEMP_REUPLOADLIST} ] && rm ${TEMP_REUPLOADLIST}

runSendLog ()
{
    SENDLOGNAME=$1
    x=1;i=1
    until [ "$i" -eq 0 ];do
        [ "$x" -gt "${SEND_MAX_TIME}" ] && {
            echoBadLog "Send: ${SENDLOGNAME} to ftp_server was failed, Please check..."
            echo "${LCD_DIR};;${CD_DIR};;${SENDLOGFILE}" >> ${TEMP_REUPLOADLIST}
            break
        }
        sendLog ${SENDLOGNAME}
        i=`echo $?`
        x=`expr $x + 1`
    done
}

[ "${T}" -eq 0 -a -e "${LCD_DIR}${TAR_LOG_DAY_NAME}" -a "${RECORD_LOG_VALUE}" -eq 0 ] && runSendLog ${TAR_LOG_DAY_NAME}
[ -e "${LCD_DIR}${TAR_LOG_HOUR_NAME}" ] && runSendLog ${TAR_LOG_HOUR_NAME}
##
# 把上面两种发送成功的记录更新到这个临时文件
#
TEMP_SENDSUCCESFILE="/var/log/temp_send_succes_${LOG_TYPEB}_${STATION}.txt"
SENDSUCCESFILE="/var/log/send_succes_${LOG_TYPEB}_${STATION}.txt"
[ "${TEMP_SEND_STATUS}" -eq 0 ] && echo "${LCD_DIR};;${CD_DIR};;${SENDLOGFILE};;$(date +%s)" > ${TEMP_SENDSUCCESFILE}
##
# 功能：断电恢复之后，发送断电当天的整天日志文件
#
[ -e ${SENDSUCCESFILE} ] && {
    LCD_DIR=`cat ${SENDSUCCESFILE}|awk -F";;" '{print $1}'`
    CD_DIR=`cat ${SENDSUCCESFILE}|awk -F";;" '{print $2}'`
    LAST_DATE_SUCCESS=`date -d @"$(cat ${SENDSUCCESFILE}|awk -F";;" '{print $4}')" +%Y-%m-%d`
    INTERVAL_TIME=`expr $(date +%s) - $(cat ${SENDSUCCESFILE}|awk -F";;" '{print $4}')`
    LAST_DAY=`echo $(date -d @"$(cat ${SENDSUCCESFILE}|awk -F";;" '{print $4}')" +%d)|sed 's/^0//g'`
    NOW_DAY=`echo $(date +%d)|sed 's/^0//g'`
    ##
    # 7000，这个值必须大于3600，且小于7200
    #+ 经测试，当等于7000时，运行结果符合预期
    #
    [ "${LAST_DAY}" -ne "${NOW_DAY}" -a "${INTERVAL_TIME}" -gt 7000 ] && {
        cd ${LCD_DIR} && {
            TEMP_SEND_FILES="${LAST_DATE_SUCCESS}.${SERVER_NAME}.nginxlog.tar.gz"
            [ -e ${TEMP_SEND_FILES} ] || tarDayLog ${TEMP_SEND_FILES}
        }
        runSendLog ${TEMP_SEND_FILES}
    }
    rm ${SENDSUCCESFILE}
}
[ -f ${TEMP_SENDSUCCESFILE} ] && mv ${TEMP_SENDSUCCESFILE} ${SENDSUCCESFILE}

##
# 重传上次发送失败的文件
#
reUploadFile ()
{
    TEMP_NEED_DO_FILE=$1
    REUPLOADLIST_NUM=$( wc -l < ${TEMP_NEED_DO_FILE} )
    [ "${REUPLOADLIST_NUM}" -ge 1 ] && {
        while read line
        do
            LCD_DIR=`echo ${line}|awk -F";;" '{print $1}'`
            CD_DIR=`echo ${line}|awk -F";;" '{print $2}'`
            REUPLOADFILENAME=`echo ${line}|awk -F";;" '{print $3}'`
            [ -f "${LCD_DIR}/${REUPLOADFILENAME}" ] && runSendLog ${REUPLOADFILENAME}
        done < ${TEMP_NEED_DO_FILE}
    }
    [ -e ${TEMP_NEED_DO_FILE} ] && rm ${TEMP_NEED_DO_FILE}
}

[ -s ${REUPLOADLIST} ] && reUploadFile ${REUPLOADLIST}
[ -f ${TEMP_REUPLOADLIST} ] && mv ${TEMP_REUPLOADLIST} ${REUPLOADLIST}
[ -f ${FTP_ERROR_LOG} ] && rm ${FTP_ERROR_LOG}

##
# 清理备份日志
#
[ -d ${LCD_DIR} ] && cd ${LCD_DIR} && {
    for FILENAME in `find . -type f -ctime +${BACK_SAVE_MAX_DAY} | awk -F/ '{print $2}'`
    do
        rm  ${FILENAME} && echoGoodLog "Clear: ${LCD_DIR}/${FILENAME}..."
    done
}

cleanRunLog ${RUN_LOG}

