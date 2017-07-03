#!/bin/bash
# Cut and upload aclog log
# by colin
# revision on 2016-06-15
########################################
# 功能说明：该脚本运用于上传aclog日志
#
# 使用说明：
#+ ./aclog_backup_and_upload.sh -f /var/log/host/jnxac.log -t tar -h SDQD-TS-JNX-HLS
# 更新说明：
#
########################################
#sleep 60	    #延时60秒运行
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
LOG_CUT_MIN=60   # 日志文件30分钟切割一次

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`cat ${CLEANLOGFILE} |wc -l`
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && {
        sed -i "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE} && echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    echoGoodLog "Script: `basename $0` run done."
    exit
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
    echoGoodLog "./`basename $0` -f/--file /var/log/host/qfgw.log [-t/--tar tar] [-h/--hostname SDQD-TS-CL-WIN]"
    echoGoodLog "Options:"
        echoGoodLog " -f/--file)"
        echoGoodLog "    必须的参数：需要切割与上传的日志文件"
        echoGoodLog " -t/--tar)"
        echoGoodLog "    可选参数：若需打包，使用方法： -t tar "
        echoGoodLog " -h/--hostname)"
        echoGoodLog "    可选参数：若一个站点存放了多个地方的相同类型日志，此时就需要设定每个日志所属站点"
        echoGoodLog "        比如：昌乐的网关日志，没有HLS，日志存储在青岛北，那加参数如下：-h SDQD-TS-CL-WIN"
        echoGoodLog " -c)"
        echoGoodLog "    可选参数：用于检查日志服务器上是否有存储日志的文件夹，没有就创建，需使用except命令，会自动安装"
        echoGoodLog "        注意：日志服务器必须要开放ssh远程登录，或者防火墙需要放行"
        echoGoodLog "        使用方法：./`basename $0` -c   ；-c后面不需要加选项"
    echoGoodLog "Example:"
    echoGoodLog "./`basename $0` -f /var/log/host/qfgw.log -t tar -h SDQD-TS-CL-WIN"
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
   exit
else
    ##
    # 脚本传参数，调用相应的函数功能
    #
    while test -n "$1";do
        case "$1" in
            --file|-f)
                shift
                checkParameter $1
                LOG_NAME=$1
                ;;
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
            -c)
                CCHECK_LOG_SERVER_DIR=$1
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
# 需要切割的日志为必须要的参数
#
checkParameter $LOG_NAME
IS_TAR=${CTAR:-notar}
HOSTNAME=${CHOSTNAME:-`hostname`}
TEMP_PRO=`echo ${PROVINCE[@]} |sed "s/ /|/g"`
STATION=`echo ${HOSTNAME} |awk -F- '{print $3}'|tr [A-Z] [a-z]`
STATION_TYPE=`echo ${HOSTNAME} |awk -F- '{print $2}'|tr [A-Z] [a-z]`
STATION_SITE=`echo ${HOSTNAME} |awk -F- '{print $1}'|tr [A-Z] [a-z] |grep -Eo "\b${TEMP_PRO}"`

#############################
# define the ftp client
LOG_TYPE="aclog"
LOG_TYPEB="aclog"
LCD_DIR="/data/${STATION}_log/${STATION}_${LOG_TYPE}"
# 日志服务器上的保存文件夹特例
#----------------------------
case ${STATION_SITE}${STATION_TYPE} in
    #sdbs) CD_DIR="/${LOG_TYPEB}/${STATION_SITE}/qdjy/${STATION}/";;
    sdbs) CD_DIR="/${LOG_TYPEB}/${STATION_SITE}/qdjy/";;
    *) CD_DIR="/${LOG_TYPEB}/${STATION_SITE}/${STATION}/";;
esac
#############################
# define the ftp server
FTPSERVER='11.11.11.11'
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

checkProgramExist(){
    PROGRAMNAME=${1?"Usage: $FUNCNAME program_install_name"}
    PROGRAMEXIST=`dpkg -l |grep -wo ${PROGRAMNAME}|wc -l`
    if [ "${PROGRAMEXIST}" -ge 1 ];then
        return 0;
    else
        /usr/bin/apt-get install ${PROGRAMNAME} -y        
        if [ $? -eq 0 ];then
            echoGoodLog "Install ${PROGRAMNAME} is successfully."
            return 0;
        else
            echoBadLog "Install ${PROGRAMNAME} was failed, Please check..."
            return 1;
        fi
    fi
}

checkLogServerDir(){
    checkProgramExist expect
    passwd=${FTPPASSWD}
    /usr/bin/expect <<-EOF
set time 1
spawn ssh -p${SSHPORT} ${FTPUSER}@${FTPSERVER}
expect {
    "*yes/no" { send "yes\r"; exp_continue }
    "*password:" { send "$passwd\r" }
}
expect "*~$"
send "cd /home/upload${CD_DIR}\r"
expect {
    "*No such file or directory" { send "mkdir -p /home/upload${CD_DIR}\r" }
}
expect "*~$"
send "exit\r"
interact
expect eof
EOF
    echo -e "\r"
}

[ ! -d ${LCD_DIR} ] && mkdir -p ${LCD_DIR}
##
# 若切割后的日志文件存在时，就退出切割命令等
#
cd ${LCD_DIR} && [ ! -f ${PUT_LOG_HOUR_NAME} ] && {
    if [ -s ${LOG_NAME} ];then
        until [ -f ${LOG_HOUR_NAME} ]
        do
            cp ${LOG_NAME} ${LOG_HOUR_NAME}
        done
        if [ $? -eq 0 -a -f "${LOG_HOUR_NAME}" ];then
            echoGoodLog "Create ${LOG_HOUR_NAME} is successfully."
        else
            echoBadLog "Create ${LOG_HOUR_NAME} was failed, Please check..."
        fi
        [ "${IS_TAR}" = "tar" ] && tarLogFile ${PUT_LOG_HOUR_NAME} ${LOG_HOUR_NAME}        
        if [ "${T}" -eq 0 -a "${DAY_LOG_TAR_NUM}" -eq 0 ];then
            TEMP_CHECK_LOG=`ls -l ${LOG_DAY_NAME} |awk '{print $5}'`
            cat ${LOG_NAME} >> ${LOG_DAY_NAME}
            [ $? -eq 0 ] || cat ${LOG_NAME} >> ${LOG_DAY_NAME}
            CHECK_LOG=`ls -l ${LOG_DAY_NAME} |awk '{print $5}'`
        else
            [ -f ${LOG_TYPE}${DAY_TIME}.txt ] || touch ${LOG_TYPE}${DAY_TIME}.txt
            TEMP_CHECK_LOG=`ls -l ${LOG_TYPE}${DAY_TIME}.txt |awk '{print $5}'`
            cat ${LOG_NAME} >> ${LOG_TYPE}${DAY_TIME}.txt
            [ $? -eq 0 ] || cat ${LOG_NAME} >> ${LOG_TYPE}${DAY_TIME}.txt
            CHECK_LOG=`ls -l ${LOG_TYPE}${DAY_TIME}.txt |awk '{print $5}'`
        fi
        echoGoodLog "CHECK: CHECK_LOG=${CHECK_LOG},TEMP_CHECK_LOG=${TEMP_CHECK_LOG}..."
        if [ "${CHECK_LOG}" -gt "${TEMP_CHECK_LOG}" ];then
            cat /dev/null > ${LOG_NAME}
            [ $? -eq 0 ] && echoGoodLog "Append: ${LOG_HOUR_NAME} to ${LOG_TYPE}_day_log is successfully."
        else
            echoBadLog "Append: ${LOG_HOUR_NAME} to ${LOG_TYPE}_day_log was failed, Please check..."
        fi
        [ "${T}" -eq 0 -a "${IS_TAR}" = "tar" -a "${DAY_LOG_TAR_NUM}" -eq 0 ] && tarLogFile ${PUT_LOG_DAY_NAME} ${LOG_DAY_NAME}
    else
        echoBadLog "Log: ${LOG_NAME} is null or not exist, Please check..."
    fi
}

##
# 检查保存文件夹目录是否存在
#
CHECK_LOG_SERVER_DIR=${CCHECK_LOG_SERVER_DIR:-"f.ck"}
[ "${CHECK_LOG_SERVER_DIR}" = "-c" ] && checkLogServerDir
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
        sleep ${SEND_WHILE_SLEEP_TIME}
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

[ "${T}" -eq 0 -a -f "${LCD_DIR}/${PUT_LOG_DAY_NAME}" -a "${DAY_LOG_TAR_NUM}" -eq 0 ] && runSendLog ${PUT_LOG_DAY_NAME}
[ -f "${LCD_DIR}/${PUT_LOG_HOUR_NAME}" ] && runSendLog ${PUT_LOG_HOUR_NAME}

##
# 把上面两种发送成功的记录更新到这个临时文件
#
TEMP_SENDSUCCESFILE="/var/log/temp_send_succes_${LOG_TYPEB}_${STATION}.txt"
SENDSUCCESFILE="/var/log/send_succes_${LOG_TYPEB}_${STATION}.txt"
[ "${TEMP_SEND_STATUS}" -eq 0 ] && echo "${LCD_DIR};;${CD_DIR};;${SENDLOGFILE};;$(date +%s)" > ${TEMP_SENDSUCCESFILE}
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
#+ 说明：重新上传函数的执行段，最好是放在后面，因为它依赖前面的FTP发送函数生成的TEMP_REUPLOADLIST清单
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
        rm ${FILENAME} && echoGoodLog "Clear: ${LCD_DIR}/${FILENAME}..."
    done
}

cleanRunLog ${RUN_LOG}