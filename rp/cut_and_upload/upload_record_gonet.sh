#!/bin/bash
# upload gonet log to ftp_server
# by colin on 2016-01-29
##################################
# 脚本说明：
#  脚本每小时运行一次，用于检测gonet是否运行正常，
#+ 同时在凌晨上传整天的打包备份文件到日志存储服务器
#
# 更新记录：
#
##################################
#sleep 60    #延时60秒运行
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

DEFAULT_TT=0
TT=${1:-$DEFAULT_TT}

PROV_STATION=`echo $(hostname) |awk -F- '{print $1}'|tr [A-Z] [a-z]|grep -Eo "^sd|^hlj"`
STATIONTYPE=`echo $(hostname) |awk -F- '{print $2}'|tr [A-Z] [a-z]`
STATIONNAME=`echo $(hostname) |awk -F- '{print $3}'|tr [A-Z] [a-z]`
LOG_TYPE='gonet'
GONETDIR='/data/store/logs/yjww/'
GONETACCESSLOGDIR='/data/store/logs/www/'
GONETACCESSLOGNAME='gonet_wonaonao_access'
CD_DIR="/${LOG_TYPE}/${PROV_STATION}/${STATIONTYPE}/${STATIONNAME}"
LCD_DIR="${GONETDIR}gonet_access_log_backup"
#############################
##
# define the ftp server
#
FTPSERVER='iamIPaddress'
FTPUSER='upload'
FTPPASSWD='thisispassword'
SSHPORT='220'
#############################

checkProgramExist(){
    PROGRAMNAME=${1?"Usage: $FUNCNAME program_install_name"}
    PROGRAMEXIST=`dpkg -l |grep -wo ${PROGRAMNAME}|wc -l`
    if [ "${PROGRAMEXIST}" -ge 1 ];then
        return 0;
    else
        apt-get install ${PROGRAMNAME} -y        
        if [ $? -eq 0 ];then
            echoGoodLog "Install ${PROGRAMNAME} is successfully."
            return 0;
        else
            echoBadLog "Install ${PROGRAMNAME} was failed, Please check..."
            return 1;
        fi
    fi
}

restartNginx(){
    /usr/sbin/service nginx restart
    if [ $? -eq 0 ];then
        echoGoodLog "Restart nginx is done."
    else
        echoBadLog "Restart nginx is failed, Please check..."
    fi
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

killNginxForLog(){
    NGINXPIDFILE="/var/run/nginx.pid"
    [ -e ${NGINXPIDFILE} ] && NGINXPID=`cat ${NGINXPIDFILE}` || NGINXPID=
    x=0
    until [ -n "${NGINXPID}" ];do
        [ $x -gt 3 ] && {
            echoBadLog "Warning: ${NGINXPIDFILE} is not exist, Please check..."
        }
        sleep 20
        x=`expr $x + 1`
    done
    kill -USR1 ${NGINXPID} && return 0 || return 1
}

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`cat ${CLEANLOGFILE} |wc -l`
    if [ "${TEMP_WC}" -gt 100000 ];then
        sed -i "1,5000d" ${CLEANLOGFILE}
        echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    fi
    echoGoodLog "Script: `basename $0` run done."
    exit 0
}

#############################
TMONTH=`date -d 'yesterday' +%Y%m`
TLASTHOUR=`date -d '1 hour ago' +%H`
TYESTERDAY=`date -d "yesterday" +%d`
TTODAY=`date +%d`
T=`echo $(date +%k) |sed 's/ //g'`
LASTDAY=`date -d '1 day ago' +%Y-%m-%d`
##
# TT=0~23时，凌晨的时候，文件目录是昨天的
#
if [ "$T" -eq "$TT" ];then
    TEMP_GONETDIR=${GONETDIR}${TMONTH}/${TYESTERDAY}/
else
    TEMP_GONETDIR=${GONETDIR}${TMONTH}/${TTODAY}/
fi

TARLOGNAME="${LOG_TYPE}${LASTDAY}.tar.gz"

tarStat(){
    if [ -e ${1?"Usage: $FUNCNAME tar_file_name"} ];then
        echoGoodLog "Tar: $1 is successfully."
    else
        echoBadLog "Tar: $1 was failed, Please check..."
    fi
}

cd ${GONETDIR} && {
    [ ! -d gonet_access_log_backup ] && mkdir gonet_access_log_backup
    cd gonet_access_log_backup && {
        if [ -e ${GONETACCESSLOGDIR}${GONETACCESSLOGNAME}.log -a -s ${GONETACCESSLOGDIR}${GONETACCESSLOGNAME}.log ];then
            [ "$T" -eq "$TT" ] && {
                mv ${GONETACCESSLOGDIR}${GONETACCESSLOGNAME}.log  . || mv ${GONETACCESSLOGDIR}${GONETACCESSLOGNAME}.log  .
                killNginxForLog && echoGoodLog "Log: ${GONETACCESSLOGNAME}.log is cut successfully." || {
                    echoBadLog "Cut: ${GONETACCESSLOGNAME}.log was failed, Please check..."
                }
            } 
        else
            echoBadLog "Log: ${GONETACCESSLOGDIR}${GONETACCESSLOGNAME}.log is not exist..."
            restartNginx
            restartPHP
        fi 
        [ -e ${TEMP_GONETDIR}yjww_${TLASTHOUR}.log ] || {
            echoBadLog "Log: ${TEMP_GONETDIR}yjww_${TLASTHOUR}.log is not exist, Please check..."
            restartPHP
        }
        [ "$T" -eq "$TT" ] && {
            [ -e ${TARLOGNAME} ] || {
                [ -d ${TEMP_GONETDIR} ] && cp -a ${TEMP_GONETDIR} .
                [ -e ${GONETACCESSLOGNAME}.log ] && GASTATNUM=0 || GASTATNUM=1
                [ -d ${TYESTERDAY} ] && GYSTATNUM=0 || GYSTATNUM=1
                case "${GASTATNUM}${GYSTATNUM}" in
                    00)
                        echoGoodLog "Tar: ${GONETACCESSLOGNAME}.log and ${TYESTERDAY} ..."
                        tar -czf ${TARLOGNAME} --remove-files ${GONETACCESSLOGNAME}.log ${TYESTERDAY}
                        ;;
                    01) 
                        echoGoodLog "Tar: ${GONETACCESSLOGNAME}.log ..."
                        tar -czf ${TARLOGNAME} --remove-files ${GONETACCESSLOGNAME}.log
                        ;;
                    10) 
                        echoGoodLog "Tar: ${TYESTERDAY} ..."
                        tar -czf ${TARLOGNAME} --remove-files ${TYESTERDAY}
                        ;;
                    *) break;;
                esac
                tarStat ${TARLOGNAME}
            }
        } 
    }
}

checkLogServerDir(){
    [ "$T" -eq "$TT" ] && {
        checkProgramExist expect
        PASSWD="${FTPPASSWD}"
        /usr/bin/expect <<-EOF
set time 1
spawn ssh -p${SSHPORT} ${FTPUSER}@${FTPSERVER}
expect {
    "*yes/no" { send "yes\r"; exp_continue }
    "*password:" { send "${PASSWD}\r" }
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
}

##
# 因阿里云服务器禁用了SSH远程端口，暂不启用该函数
#
#checkLogServerDir
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
prompt
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
        return 0
    else
        echoBadLog "Send: ${SENDLOGFILE} more than $x time."
        sleep 30
        return 1
    fi
}

REUPLOADLIST="/var/log/re_upload_list_${LOG_TYPE}_${STATIONNAME}.log"
TEMP_REUPLOADLIST="/var/log/temp_re_upload_list_${LOG_TYPE}_${STATIONNAME}.log"
[ -f ${TEMP_REUPLOADLIST} ] && rm ${TEMP_REUPLOADLIST}
runSendLog(){
    SENDLOGNAME=$1
    x=1;i=1
    until [ "$i" -eq 0 ];do
        [ "$x" -gt 6 ] && {
            echoBadLog "Send: ${SENDLOGNAME} to ftp_server was failed, Please check..."
            echo "${LCD_DIR};;${CD_DIR};;${SENDLOGFILE}" >> ${TEMP_REUPLOADLIST}
            break
        }
        sendLog "${SENDLOGNAME}"
        i=`echo $?`
        x=`expr $x + 1`
    done
}

[ "${T}" -eq "$TT" -a -e "${LCD_DIR}/${TARLOGNAME}" ] && runSendLog ${TARLOGNAME}
##
# 断电之后，若隔天恢复，就打包并上传断电那天的gonet文件
#
TEMP_SUCCESSRUN="/var/log/temp_send_succes_${LOG_TYPE}_${STATIONNAME}.txt"
echo "$(date +%s)" > ${TEMP_SUCCESSRUN}
SUCCESSRUN="/var/log/send_succes_${LOG_TYPE}_${STATIONNAME}.txt"
[ -e ${SUCCESSRUN} ] && {
    LAST_SUCCESS_DAY=`date -d @"$(cat ${SUCCESSRUN})" +%Y-%m-%d`
    MONTH_DIR=`date -d @"$(cat ${SUCCESSRUN})" +%Y%m`
    DAY_DIR=`date -d @"$(cat ${SUCCESSRUN})" +%d`
    INTERVAL_TIME=`expr $(date +%s) - $(cat ${SUCCESSRUN})`
    LAST_DAY=`echo $(date -d @"$(cat ${SUCCESSRUN})" +%d)|sed 's/^0//g'`
    NOW_DAY=`echo $(date +%d)|sed 's/^0//g'`
    [ "${LAST_DAY}" -ne "${NOW_DAY}" -a "${INTERVAL_TIME}" -gt 7000 ] && {
        cd ${LCD_DIR} && [ -d ${GONETDIR}${MONTH_DIR}/${DAY_DIR} ] && {
            cp -a ${GONETDIR}${MONTH_DIR}/${DAY_DIR} . && {
                tar -czf ${LOG_TYPE}${LAST_SUCCESS_DAY}.tar.gz --remove-files  ${DAY_DIR}
                tarStat ${LOG_TYPE}${LAST_SUCCESS_DAY}.tar.gz
                runSendLog ${LOG_TYPE}${LAST_SUCCESS_DAY}.tar.gz
            }
        } 
    }
    rm ${SUCCESSRUN}
}
[ -f ${TEMP_SUCCESSRUN} ] && mv ${TEMP_SUCCESSRUN} ${SUCCESSRUN}

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
#-------------------
[ -f ${FTP_ERROR_LOG} ] && rm ${FTP_ERROR_LOG}

cleanRunLog ${RUN_LOG}
