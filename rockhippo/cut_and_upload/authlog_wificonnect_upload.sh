#!/bin/bash
#Cut and upload wificonnect log
#by colin
#revision on 2016-02-01
########################################
#功能说明：该脚本运用于上传wificonnect日志
########################################
#wificonnect.2015-12-02-22.log
#sleep 60	    #延时60秒运行
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/cron_scripts_run_wificonnect.log'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoGoodLog "Now, Script: `basename $0` run."

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`cat ${CLEANLOGFILE} |wc -l`
    [ "${TEMP_WC}" -gt 100000 ] && {
        sed -i "1,5000d" ${CLEANLOGFILE}
        [ $? -eq 0 ] && echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    echoGoodLog "Script: `basename $0` run done."
    exit
}

#define the ftp client
LOG_TYPE="wificonnect"
LCD_DIR="/data/www/jiaoyun/jiaoyun_auth/stats"
CD_DIR="/jiaoyun_auth_tongji/stats"
#############################
#define the ftp server
FTPSERVER='11.11.11.11'
FTPUSER='upload'
FTPPASSWD='thisispasswd'
SSHPORT='220'
#############################
T=`echo $(date +%k) |sed 's/ //g'`
LAST_T=`echo $(date -d "1 hour ago" +%k) |sed 's/ //g'`
DAY_TIME=`date +%Y-%m-%d`
LAST_HOUR_TIME=`date -d "1 hour ago" +%Y-%m-%d-%H`
LOG_HOUR_NAME="${LOG_TYPE}.${LAST_HOUR_TIME}.log" 
FTP_LOG_DIR="/tmp/ftp_err"
[ -d ${FTP_LOG_DIR} ] || mkdir -p ${FTP_LOG_DIR}
FTP_ERROR_LOG="${FTP_LOG_DIR}/ftp_temp_${LOG_TYPE}_err$$.log"

#FTP自动化上传函数
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
    #统计前面FTP运行输出的错误日志记录行数
    LOG_COUNT=`grep -w "^226" ${FTP_ERROR_LOG}|wc -l`
    if [ ${LOG_COUNT} -eq 1 ];then
        echoGoodLog "Send: ${SENDLOGFILE} to ftp_server was successfully."
        TEMP_SEND_STATUS=0
        return 0
    else
        echoBadLog "Send: ${SENDLOGFILE} more than $x time."
        TEMP_SEND_STATUS=1
        sleep 30
        return 1
    fi
}

REUPLOADLIST="/var/log/reupload_list_${LOG_TYPE}.log"
TEMP_REUPLOADLIST="/var/log/temp_reupload_list_${LOG_TYPE}.log"
[ -f ${TEMP_REUPLOADLIST} ] && rm ${TEMP_REUPLOADLIST}
runSendLog(){
    SENDLOGNAME=$1
    x=1;i=1
    until [ "$i" -eq 0 ];do
        [ $x -gt 6 ] && {
            echoBadLog "Send: ${SENDLOGNAME} to ftp_server was failed, Please check..."
            echo "${LCD_DIR};;${CD_DIR};;${SENDLOGFILE}" >> ${TEMP_REUPLOADLIST}
            break
        }
        sendLog "${SENDLOGNAME}"
        i=`echo $?`
        x=`expr $x + 1`
    done
}

[ -f "${LCD_DIR}/${LOG_HOUR_NAME}" ] && runSendLog ${LOG_HOUR_NAME}

#重传上次发送失败的文件
reUploadFile(){
    TEMP_NEED_DO_FILE=$1
    REUPLOADLIST_NUM=`cat ${TEMP_NEED_DO_FILE}|wc -l`
    [ ${REUPLOADLIST_NUM} -ge 1 ] && {
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
cleanRunLog ${RUN_LOG}
