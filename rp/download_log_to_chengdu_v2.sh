#!/bin/bash
# download everydaylog from aliyun to chengdu
# by colin on 2015-12-07
##################################
# 脚本说明：
#+ 脚本每天运行一次，用于把远程服务器上的整天日志文件下载到成都本地存储
#+ 在指定的目录下寻找匹配的文件，用ftp下载到本地存储
# 更新记录：
#+ 12月7日，重写脚本
#
##################################
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
#sleep 60    #延时60秒运行
RUN_LOG='/var/log/cron_scripts_run.log'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoGoodLog "Now, Script: `basename $0` run."

EMAIL=(
    colin@rockhippo.cn
)

FTPSERVERIP='iamIPaddress'

##
# 需要检查的目录
#
DIR_LIST=(
    /home/upload/aclog
    /home/upload/eglog
    /home/upload/nginxlog
    /home/upload/mysql
    /home/upload/gonet
    /home/upload/72/mysql
)

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=$(wc -l ${CLEANLOGFILE} |awk '{print $1}')
    [ "${TEMP_WC}" -gt 100000 ] && {
        sed -i "1,5000d" ${CLEANLOGFILE}
        echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    echoGoodLog "Script: `basename $0` run done."
    exit
}

TEMP_EMAIL_FILES="/tmp/temp_email_files$$.txt"
[ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES}

addToEmailFile(){
    cat >>${TEMP_EMAIL_FILES} <<EOF
GET: failed to download log $2$1 from aliyun, Please check!
EOF
}

sendEmail(){
    EMAILFILE=${1?"Usage: $FUNCNAME email_file_name"}
    [ $(wc -l ${EMAILFILE} |awk '{print $1}') -eq 0 ] || { 
        for emailaddr in ${EMAIL[@]}
        do
            dos2unix -k ${EMAILFILE} 
            mail -s "Failed to download logs from aliyun" ${emailaddr} < ${EMAILFILE}
            echoGoodLog "Send email to ${emailaddr}, Please check ..."
        done
    
    }
    [ -f ${EMAILFILE} ] && rm -rf ${EMAILFILE}
}

#LASTDAY='2016-03-05'
#NOWDAY='2016-03-06'
LASTDAY=`date -d '1 day ago' +%Y-%m-%d`
NOWDAY=`date +%Y-%m-%d`
T=`echo $(date +%k) |sed "s/ //g"`

##
# 根据需要检测的目录最后一个字段去匹配检查文件名
#
matchLogName(){
    DIR=$1
    CASECONDITION=`echo ${DIR} |awk -F/ '{print $NF}'`
    case ${CASECONDITION} in
        aclog)
            if [ "$T" -ge 7 ];then
                MATCHLOG="aclog${LASTDAY}_old.txt"
            else
                MATCHLOG="aclog${LASTDAY}.txt"
            fi
            ;;
        eglog)
            MATCHLOG="gateway${LASTDAY}.tar.gz"
            ;;
        nginxlog)
            MATCHLOG="${LASTDAY}.*.nginxlog.tar.gz"
            ;;
        gonet)
            MATCHLOG="gonet${LASTDAY}.tar.gz"
            ;;
        mysql)
            MATCHLOG="${LASTDAY}.*.tar.gz"
            ;;
    esac
}

TEMPFINDLOGLIST="/tmp/temp_find_log_list$$.txt"
FTPERRORDIR="/tmp/ftp_err/"
[ -d ${FTPERRORDIR} ] || mkdir -p ${FTPERRORDIR}
FTPERRORLOG="${FTPERRORDIR}ftp_temp_download_err$$.log"

##
# 调用函数参数分别为：需要下载的文件名、阿里云服务器文件存储目录、成都本地存储目录
#
ftpGetLog(){
    timeout 2h ftp -inv ${FTPSERVERIP} 21 > ${FTPERRORLOG} << _EOF_
user upload chriscao
passive
bin
prompt
lcd $3
cd  $2
get $1
bye
_EOF_
    FILESIZE=$(ssh -p 22000 upload@${FTPSERVERIP} ls -l /home/upload/$2$1 | awk '{print $5}')
    log_count=`grep -w "^226" ${FTPERRORLOG}|wc -l`
    if [ ${log_count} -eq 1 ];then
        echoGoodLog "Get: $2$1 was successfully."
        GET_FILESIZE=$(ls -l $3$1 |awk '{print $5}')
        [ "${FILESIZE}" -eq "${GET_FILESIZE}" ] || addToEmailFile $1 $2
        return 0
    else
        echoBadLog "Get: $2$1 more than $4 time."
        sleep 20
        return 1
    fi
}

REUPLOADLIST="/var/log/redownload_list_aly_to_cd.log"
TEMP_REUPLOADLIST="/var/log/temp_redownload_list_aly_to_cd.log"
[ -f ${TEMP_REUPLOADLIST} ] && rm ${TEMP_REUPLOADLIST}

whileDownloadLog(){
    WHILEFILE=$1
    WHILENUM=$(wc -l ${WHILEFILE} |awk '{print $1}')
    for((i=1;i<=${WHILENUM};i++))
    do
        TEMPLINE=`sed -n "${i}p" ${WHILEFILE}`
        LOGNAME=`echo ${TEMPLINE}|awk -F/ '{print $NF}'`
        DIRNAME=`echo ${TEMPLINE}|awk -F/ '{$NF="";print $0}'|sed "s/ /\//g"`    
        LOGBAKDIR=`echo ${DIRNAME} |sed "s#/home/upload#/data/log_backup#g"`
        [ -d ${LOGBAKDIR} ] || mkdir -p ${LOGBAKDIR}
        ALIYUNLOGDIR=`echo ${DIRNAME} |sed "s#/home/upload##g"`
        TARSTATSNUM=`echo ${LOGNAME} |grep -Eo ".tar.gz$"|wc -l`
        [ ${TARSTATSNUM} -eq 0 ] && {
            ssh -p 22000 upload@${FTPSERVERIP} tar -czf ${DIRNAME}${LOGNAME%.txt}.tar.gz ${TEMPLINE}
            LOGNAME=${LOGNAME%.txt}.tar.gz
            echoGoodLog "TAR: ${DIRNAME}${LOGNAME}..."
        }
        ############################
        THREETIME=1
        FTPGETLOGSTATS=1
        until [ ${FTPGETLOGSTATS} -eq 0 ];do
            [ ${THREETIME} -gt 3 ] && {
                echoBadLog "Get: ${TEMPLINE} was failed, Please check..."
                echo "${LOGNAME};;${ALIYUNLOGDIR};;${LOGBAKDIR}" >> ${TEMP_REUPLOADLIST}
                addToEmailFile ${LOGNAME} ${DIRNAME}
                break
            }
            if [ -e ${LOGBAKDIR}${LOGNAME} ];then
                FTPGETLOGSTATS=0
                echoGoodLog "LOG: ${LOGBAKDIR}${LOGNAME} is exist."
            else
                ftpGetLog ${LOGNAME} ${ALIYUNLOGDIR} ${LOGBAKDIR} ${THREETIME}
                FTPGETLOGSTATS=`echo $?`
                THREETIME=`expr ${THREETIME} + 1`
            fi
        done
        [ -e ${FTPERRORLOG} ] && rm ${FTPERRORLOG}
    done
    return 0
}

for dirname in ${DIR_LIST[@]}
do
    matchLogName ${dirname}
    ssh -p 22000 upload@${FTPSERVERIP} find ${dirname} -type f -name ${MATCHLOG} > ${TEMPFINDLOGLIST}
    whileDownloadLog ${TEMPFINDLOGLIST}
    [ -e ${TEMPFINDLOGLIST} ] && rm ${TEMPFINDLOGLIST}
done


##
# 重新下载上次GET失败的文件
#
reUploadFile(){
    TEMP_NEED_DO_FILE=$1
    REUPLOADLIST_NUM=$(wc -l ${TEMP_NEED_DO_FILE} |awk '{print $1}')
    [ "${REUPLOADLIST_NUM}" -ge 1 ] && {
        while read line
        do
            #${LOGNAME};;${ALIYUNLOGDIR};;${LOGBAKDIR}
            LCD_DIR=`echo ${line}|awk -F";;" '{print $3}'`
            CD_DIR=`echo ${line}|awk -F";;" '{print $2}'`
            REUPLOADFILENAME=`echo ${line}|awk -F";;" '{print $1}'`
            [ -f "${LCD_DIR}/${REUPLOADFILENAME}" ] && ftpGetLog ${REUPLOADFILENAME} ${CD_DIR} ${LCD_DIR}
        done < ${TEMP_NEED_DO_FILE}
    }
    [ -e ${TEMP_NEED_DO_FILE} ] && rm ${TEMP_NEED_DO_FILE}
}

[ -s ${REUPLOADLIST} ] && reUploadFile ${REUPLOADLIST}
[ -f ${TEMP_REUPLOADLIST} ] && mv ${TEMP_REUPLOADLIST} ${REUPLOADLIST}

sendEmail ${TEMP_EMAIL_FILES}
cleanRunLog ${RUN_LOG}
