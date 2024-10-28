#!/bin/bash
# Cut and upload gateway log
# by colin
# revision on 2016-06-13
########################################
# 功能说明：该脚本运用于上传gateway日志
#
# 使用说明：
#+ ./upload_gatewaylog.sh -t tar -h SDQD-TS-CL-WIN
# 更新说明：
#
########################################
sleep 60	    #延时60秒运行
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
LOG_CUT_MIN=60

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

##
# 脚本帮助提示函数
#
scriptsHelp(){
    echoBadLog "======================================="
    echoGoodLog "Usage parameters:"
    echoGoodLog "./`basename $0` -w iamIPaddress [-t/--tar tar] [-h/--hostname SDQD-TS-CL-WIN]"
    echoGoodLog "Options:"
        echoGoodLog " -w/--winip)"
        echoGoodLog "    必须参数：存储日志的win服务器IP，使用方法： -w iamIPaddress "
        echoGoodLog " -t/--tar)"
        echoGoodLog "    可选参数：若需打包，使用方法： -t tar "
        echoGoodLog " -h/--hostname)"
        echoGoodLog "    可选参数：若一个站点存放了多个地方的相同类型日志，此时就需要设定每个日志所属站点"
        echoGoodLog "        比如：昌乐的网关日志，没有HLS，日志存储在青岛北，那加参数如下：-h SDQD-TS-CL-WIN"
    echoGoodLog "Example:"
    echoGoodLog "./`basename $0` -w iamIPaddress -t tar -h SDQD-TS-CL-WIN"
    echoBadLog "======================================="
}

checkParameter(){
    PARAMETER=${1:-null}
    PARAMETER_STATUS=`echo "${PARAMETER}" |grep "^-"|wc -l`
    if [ "${PARAMETER_STATUS}" -eq 1 -o "${PARAMETER}" = "null" ];then
        scriptsHelp
        echoBadLog "参数错误，请重新输入。"
        exit
    fi
}

##
# 判断是否带参数
#
if [ -z "$*" ];then
   scriptsHelp
else
    ##
    # 脚本传参数，调用相应的函数功能
    #
    while test -n "$1";do
        case "$1" in
            --tar|-t)
                shift
                checkParameter $1
                CTAR=$1
                ;;
            --hostname|-h)
                shift
                checkParameter $1
                CHOSTNAME=$1
                ;;
            --winip|-w)
                shift
                checkParameter $1
                CWINIP=$1
                ;;
            *)
                echoBadLog "Unknown argument: $1"
                scriptsHelp
                exit
                ;;
        esac
        shift
    done
fi

##
# WINIP为必须的参数
#
checkParameter ${CWINIP}
IS_TAR=${CTAR:-notar}
HOSTNAME=${CHOSTNAME:-`hostname`}
TEMP_PRO=`echo ${PROVINCE[@]} |sed "s/ /|/g"`
STATION=`echo ${HOSTNAME} |awk -F- '{print $3}'|tr [A-Z] [a-z]`
STATION_TYPE=`echo ${HOSTNAME} |awk -F- '{print $2}'|tr [A-Z] [a-z]`
STATION_SITE=`echo ${HOSTNAME} |awk -F- '{print $1}'|tr [A-Z] [a-z] |grep -Eo "\b${TEMP_PRO}"`

#############################
# define the ftp client
#
LOG_TYPE="gateway"
LOG_TYPEB="eglog"
LCD_DIR="/data/${STATION}_log/${STATION}_${LOG_TYPE}"
CD_DIR="/${LOG_TYPEB}/${STATION_SITE}/${STATION}/"
MNT_DIR='/mnt'
MNT_LOG_TYPE="gatewaylog"
WIN_IP="${CWINIP}"
WIN_DIR='oldeglog'
#############################
# define the ftp server
#
FTPSERVER='iamIPaddress'
FTPUSER='upload'
FTPPASSWD='thisispassword'
SSHPORT='220'
#############################

T=`echo $(date +%k) |sed 's/ //g'`
#LAST_T=`echo $(date -d "1 hour ago" +%k) |sed 's/ //g'`
DAY_TIME=`date +%Y-%m-%d`
LAST_DAY_TIME=`date -d "yesterday" +%Y-%m-%d`
LAST_HOUR_TIME=`date +%Y-%m-%d-%H`
FILENUM=`expr $(date +%M|sed 's/^0//g') / ${LOG_CUT_MIN}`
DAY_LOG_TAR_NUM="${FILENUM}"
[[ "${FILENUM}" -eq 0 ]] && {
    FILENUM=`expr 60 / ${LOG_CUT_MIN}`
    LAST_HOUR_TIME=`date -d "1 hour ago" +%Y-%m-%d-%H`
}

##
# 为兼容旧版本，当60分钟切割一次时，就和之前旧版本文件名一样咯
#
if [ ${LOG_CUT_MIN} -eq 60 ];then
    LOG_HOUR_NAME="${LOG_TYPE}${LAST_HOUR_TIME}.txt" 
else
    LOG_HOUR_NAME="${LOG_TYPE}${LAST_HOUR_TIME}-${FILENUM}.txt" 
fi

LOG_DAY_NAME="${LOG_TYPE}${LAST_DAY_TIME}.txt" 
case "${IS_TAR}" in
    "tar")
        PUT_LOG_DAY_NAME="${LOG_DAY_NAME%.txt}.tar.gz"
        PUT_LOG_HOUR_NAME="${LOG_HOUR_NAME%.txt}.tar.gz"
        ;;
    "notar")
        PUT_LOG_DAY_NAME="${LOG_DAY_NAME}"
        PUT_LOG_HOUR_NAME="${LOG_HOUR_NAME}"
        ;;
esac

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

#检测win服务器是否在线
WIN_STATUS=`ping -c 4 ${WIN_IP} |grep "packet loss" |awk -F, '{print $(NF-1)}'|awk '{print $1}'|sed 's/%//g'`
#若ping 4次的话，丢包率大于50，就算失败
if [ ${WIN_STATUS} -gt 50 ];then
    echoBadLog "Ping: win_eglog server is ${WIN_STATUS}% packet loss, Please check..."
else
    CHECK_MNT=`df -hP|grep "${WIN_DIR}" |wc -l`
    if [ ${CHECK_MNT} -le 0 ];then
        mount -t cifs -o username=administrator,password='W_zMi6)7sA)XJ?~RT2|~' //${WIN_IP}/${WIN_DIR} ${MNT_DIR} && {
        echoGoodLog "Mount: win_eglog server was successfully."
        } || echoBadLog "Mount: win_eglog server was failed, Please check..."
    else
        echoGoodLog "Do not need to mount."
    fi
fi

[ ! -d ${LCD_DIR} ] && mkdir -p ${LCD_DIR}
cd ${LCD_DIR} && {
    [ -e ${PUT_LOG_HOUR_NAME} ] || {
        [ -f ${MNT_DIR}/${MNT_LOG_TYPE}$(date +%Y-%m-%d-%H).txt ] && {
            mv ${MNT_DIR}/${MNT_LOG_TYPE}$(date +%Y-%m-%d-%H).txt ${LOG_HOUR_NAME} && [ -s ${LOG_HOUR_NAME} ] && {
                if [ ${T} -eq 0 -a "${DAY_LOG_TAR_NUM}" -eq 0 ];then
                    TEMP_CHECK_LOG=`ls -l ${LOG_DAY_NAME} |awk '{print $5}'`
                    cat ${LOG_HOUR_NAME} >> ${LOG_DAY_NAME} || cat ${LOG_HOUR_NAME} >> ${LOG_DAY_NAME}
                    CHECK_LOG=`ls -l ${LOG_DAY_NAME} |awk '{print $5}'`
                else
                    [ -f ${LOG_TYPE}${DAY_TIME}.txt ] || touch ${LOG_TYPE}${DAY_TIME}.txt
                    TEMP_CHECK_LOG=`ls -l ${LOG_TYPE}${DAY_TIME}.txt |awk '{print $5}'`
                    cat ${LOG_HOUR_NAME} >> ${LOG_TYPE}${DAY_TIME}.txt || cat ${LOG_HOUR_NAME} >> ${LOG_TYPE}${DAY_TIME}.txt
                    CHECK_LOG=`ls -l ${LOG_TYPE}${DAY_TIME}.txt |awk '{print $5}'`
                fi
                [ "${IS_TAR}" = "tar" ] && tarLogFile ${PUT_LOG_HOUR_NAME} ${LOG_HOUR_NAME}
                echoGoodLog "CHECK: CHECK_LOG=${CHECK_LOG},TEMP_CHECK_LOG=${TEMP_CHECK_LOG}..."
                if [ "${CHECK_LOG}" -gt "${TEMP_CHECK_LOG}" ];then
                    echoGoodLog "Backup: ${LOG_HOUR_NAME} is successfully."
                else
                    echoBadLog "Backup: ${LOG_HOUR_NAME} was failed, Please check..."
                fi
            }
        } || echoBadLog "LOG: ${MNT_DIR}/${MNT_LOG_TYPE}$(date +%Y-%m-%d-%H).txt is not exist, Please check..."
    }
    [ -e ${PUT_LOG_DAY_NAME} ] || {
        [ -f ${LOG_DAY_NAME} ] && [ "${T}" -eq 0 -a "${IS_TAR}" = "tar" -a "${DAY_LOG_TAR_NUM}" -eq 0 ] && tarLogFile ${PUT_LOG_DAY_NAME} ${LOG_DAY_NAME}
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

REUPLOADLIST="/var/log/reupload_list_${LOG_TYPEB}_${STATION}.log"
TEMP_REUPLOADLIST="/var/log/temp_reupload_list_${LOG_TYPEB}_${STATION}.log"
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

[ -f "${LCD_DIR}/${PUT_LOG_HOUR_NAME}" ] && runSendLog ${PUT_LOG_HOUR_NAME}
[ "${T}" -eq 0 -a -f "${LCD_DIR}/${PUT_LOG_DAY_NAME}" -a "${DAY_LOG_TAR_NUM}" -eq 0 ] && runSendLog ${PUT_LOG_DAY_NAME}
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
