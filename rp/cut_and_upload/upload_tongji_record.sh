#!/bin/bash
# upload tongji record log
# by colin
# revision on 2016-05-16
########################################
# 功能说明：该脚本运用于上传新版统计record日志文件
#
# 2016-05-16.tar.gz
#
# 使用说明：
#+ ./upload_tongji_record.sh /ts_record/hlj/ts/qqhrn qqhrnweb
# 更新说明：
#
########################################
#sleep 60       #延时60秒运行
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
RUNLOG_MAX_NUM=100000
RUNLOG_MAX_DELNUM=5000
SEND_MAX_TIME=6
SEND_WHILE_SLEEP_TIME=30
BACK_SAVE_MAX_DAY=180

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`cat ${CLEANLOGFILE} |wc -l`
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && {
        sed -i "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE} && echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    echoGoodLog "Script: `basename $0` run done."
    exit 0
}

##
# 省份数组
#
PROVINCE=(
    sd
    hlj
    sc
)

HOSTNAME=$(hostname)
STATION=`echo ${HOSTNAME} |awk -F- '{print $3}'|tr [A-Z] [a-z]`
SERVERNAME=${2?"参数2，为服务器类型，比如jyweb，qdnweb1，qdnweb2"}

T=`echo $(date +%k) |sed 's/ //g'`
LAST_DATE_TIME=`date -d "yesterday" +%Y-%m-%d`
PUT_LOG_DAY_NAME="${LAST_DATE_TIME}.${SERVERNAME}.tar.gz"
#############################
# define the ftp client
#
CD_DIR=${1?"参数1需设置为ftp服务器端日志存储路径"}
LOG_TYPE="record"
LCD_DIR="/data/store/logs/record"
#############################
# define the ftp server
#
FTPSERVER='iamIPaddress'
FTPUSER='upload'
FTPPASSWD='thisispassword'
SSHPORT='220'
#############################

tarLogFile(){
    TARTONAME=${1?"Usage: $FUNCNAME tar_file_name need_tar_file_name"}
    FROMLOG=$2
    #tar -czf ${TARTONAME} --remove-files ${FROMLOG}
    tar -czf ${TARTONAME} ${FROMLOG}
    if [ -e ${TARTONAME} ];then
        echoGoodLog "Tar: ${TARTONAME} is successfully."
    else
        echoBadLog "Tar: ${TARTONAME} was failed, Please check..."
    fi
}

##
# 打包日志文件
#
cd ${LCD_DIR} && {
    [ -e ${PUT_LOG_DAY_NAME} ] || {
        if [ -d ${LAST_DATE_TIME} ];then
            tarLogFile ${PUT_LOG_DAY_NAME} ${LAST_DATE_TIME}
        else
            echoBadLog "The ${LCD_DIR}/${LAST_DATE_TIME} is not exists, Please check..."
        fi
    }
}

FTP_LOG_DIR="/tmp/ftp_err"
[ -d ${FTP_LOG_DIR} ] || mkdir -p ${FTP_LOG_DIR}
FTP_ERROR_LOG="${FTP_LOG_DIR}/ftp_temp_${LOG_TYPE}_err$$.log"

##
# FTP自动化上传函数
#
sendLog(){
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
        sleep "${SEND_WHILE_SLEEP_TIME}"
        return 1
    fi
}

REUPLOADLIST="/var/log/reupload_list_${LOG_TYPE}_${STATION}.log"
TEMP_REUPLOADLIST="/var/log/temp_reupload_list_${LOG_TYPE}_${STATION}.log"
[ -f ${TEMP_REUPLOADLIST} ] && rm ${TEMP_REUPLOADLIST}
runSendLog(){
    SENDLOGNAME=$1
    x=1;i=1
    until [ "$i" -eq 0 ];do
        [ "$x" -gt "${SEND_MAX_TIME}" ] && {
            echoBadLog "Send: ${SENDLOGNAME} to ftp_server was failed, Please check..."
            echo "${LCD_DIR};;${CD_DIR};;${SENDLOGFILE}" >> ${TEMP_REUPLOADLIST}
            break
        }
        sendLog "${SENDLOGNAME}"
        i=`echo $?`
        x=`expr $x + 1`
    done
}

[ "${T}" -eq 0 -a -f "${LCD_DIR}/${PUT_LOG_DAY_NAME}" ] && runSendLog ${PUT_LOG_DAY_NAME}
##
# 把上面两种发送成功的记录更新到这个临时文件
#
TEMP_SENDSUCCESFILE="/var/log/temp_send_succes_${LOG_TYPE}_${STATION}.txt"
SENDSUCCESFILE="/var/log/send_succes_${LOG_TYPE}_${STATION}.txt"
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
    [ "${LAST_DAY}" -ne "${NOW_DAY}" -a "${INTERVAL_TIME}" -gt 7000 ] && {
        if [ "${IS_TAR}" = "tar" ];then
            cd ${LCD_DIR} && {
                TEMP_SEND_FILES="${LOG_TYPE}${LAST_DATE_SUCCESS}.tar.gz"
                [ -e ${TEMP_SEND_FILES} ] || tarLogFile ${TEMP_SEND_FILES} ${LOG_TYPE}${LAST_DATE_SUCCESS}.txt
            }
        else
            TEMP_SEND_FILES="${LOG_TYPE}${LAST_DATE_SUCCESS}.txt"
        fi
        runSendLog ${TEMP_SEND_FILES}
    }
    rm ${SENDSUCCESFILE}
}
[ -f ${TEMP_SENDSUCCESFILE} ] && mv ${TEMP_SENDSUCCESFILE} ${SENDSUCCESFILE}

##
# 重传上次发送失败的文件
#
reUploadFile(){
    TEMP_NEED_DO_FILE=$1
    REUPLOADLIST_NUM=`cat ${TEMP_NEED_DO_FILE}|wc -l`
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
# 清理超过90天的备份日志
#
[ -d ${LCD_DIR} ] && cd ${LCD_DIR} && {
    for FILENAME in `find . -type f -ctime +"${BACK_SAVE_MAX_DAY}" | awk -F/ '{print $2}'`
    do
        rm  ${FILENAME} && echoGoodLog "Clear: ${LCD_DIR}/${FILENAME}..."
    done
}

cleanRunLog ${RUN_LOG}