#!/bin/bash
#download everydaylog from aliyun to chengdu
#by colin on 2015-12-01
##################################
#脚本说明：
#脚本每天运行一次，用于把远程服务器上的整天日志文件下载到成都本地存储
#
#更新记录：
#
##################################
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

#需要检查的省份
NEED_TO_DONE=(
    sd
    hlj
)

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=$(wc -l ${CLEANLOGFILE})
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
GET: failed to download log $2/$1 from aliyun, Please check!
EOF
}

sendEmail(){
    EMAILFILE=${1?"Usage: $FUNCNAME email_file_name"}
    [ `cat ${EMAILFILE}|wc -l` -eq 0 ] || { 
        for emailaddr in ${EMAIL[@]}
        do
            dos2unix -k ${EMAILFILE} 
            mail -s "Failed to download logs from aliyun" ${emailaddr} < ${EMAILFILE}
            echoGoodLog "Send email to ${emailaddr}, Please check ..."
        done
        [ -f ${EMAILFILE} ] && rm -rf ${EMAILFILE}
    }
}

LASTDAY=`date -d '1 day ago' +%Y-%m-%d`
T=`echo $(date +%k) |sed "s/ //g"`

matchLogName(){
    DIR=$1
    CASECONDITION=`echo ${DIR} |awk -F/ '{print $4}'`
    case ${CASECONDITION} in
        aclog)
            if [ $T -ge 7 ];then
                MATCHLOG="aclog${LASTDAY}_old.txt"
            else
                MATCHLOG="aclog${LASTDAY}.txt"
            fi
            ;;
        eglog)MATCHLOG="gateway*${LASTDAY}.txt";;
        nginxlog)MATCHLOG="${LASTDAY}.*.nginxlog.tar.gz";;
        gonet)MATCHLOG="gonet${LASTDAY}.tar.gz";;
        mysql)MATCHLOG="$(date +%Y-%m-%d).rht_*.tar.gz";;
    esac
}

TEMPCHECKLOGLIST="/tmp/temp_check_log_list$$.txt"
FTPERRORDIR="/tmp/ftp_err/"
[ -d ${FTPERRORDIR} ] || mkdir -p ${FTPERRORDIR}
FTPERRORLOG="${FTPERRORDIR}ftp_temp_download_err$$.log"

ftpGetLog(){
    timeout 1h ftp -inv iamIPaddress 21 > ${FTPERRORLOG} << _EOF_
    user upload chriscao
    passive
    bin
    prompt
    lcd $3
    cd  $2
    get $1
    bye
_EOF_
    log_count=`grep "^226" ${FTPERRORLOG}|wc -l`
    [ ${log_count} -eq 1 ] && return 0 || return 1
}

#调用函数参数分别为：需要下载的文件名、阿里云服务器文件存储目录、成都本地存储目录
runFtpGetLog(){
    ftpGetLog $1 $2 $3
    if [ $? -eq 0 ];then
        echoGoodLog "Get: $2/$1 was successfully."
        [ ${RMTARFILENUM} -eq 1 ] && {
            ssh -p 22000 upload@iamIPaddress rm /home/upload"$2"/${TEMPTARFILENAME}.tar.gz
            RMTARFILENUM=0
        }
        return 0
    else
        echoBadLog "Get: $2/$1 more than $x time."
        sleep 20
        return 1
    fi
}

getLogFileToChengDu(){
    ALIYUNFTPDIR=${1?"Usage: $FUNCNAME aliyun_ftp_dir chengdu_save_dir"}
    CHENGDUSAVEDIR=$2
    [ -f ${TEMPCHECKLOGLIST} ] && {
        while read line
        do
            RMTARFILENUM=0
            FTPGETFILENAME=`echo "$line" |awk -F/ '{print $NF}'`
            TEMPNUM=`echo ${FTPGETFILENAME} |grep -Eo ".tar.gz$"|wc -l`
            [ ${TEMPNUM} -eq 0 ] && {
                TEMPTARFILENAME=`echo ${FTPGETFILENAME} |grep -Eo "[a-z]{5,10}[0-9]{4}(-[0-9]{2}){2}"`
                [ -e ${CHENGDUSAVEDIR}/${TEMPTARFILENAME}.tar.gz ] || {
                    ssh -p 22000 upload@iamIPaddress tar -czf /home/upload${ALIYUNFTPDIR}/${TEMPTARFILENAME}.tar.gz /home/upload${ALIYUNFTPDIR}/${FTPGETFILENAME}
                    echoGoodLog "TAR: /home/upload${ALIYUNFTPDIR}/${TEMPTARFILENAME}.tar.gz..."
                    FTPGETFILENAME=${TEMPTARFILENAME}.tar.gz
                    RMTARFILENUM=1
                }
            }
            x=1
            i=1
            until [ "$i" -eq 0 ];do
                [ $x -gt 3 ] && {
                    echoBadLog "Get: $1/${FTPGETFILENAME} was failed, Please check..."
                    addToEmailFile ${FTPGETFILENAME} ${ALIYUNFTPDIR}
                    break
                }
                [ ${TEMPNUM} -eq 0 ] && {
                    TEMPTARFILENAME=`echo ${FTPGETFILENAME} |grep -Eo "[a-z]{5,10}[0-9]{4}(-[0-9]{2}){2}"`
                    FTPGETFILENAME=${TEMPTARFILENAME}.tar.gz
                }
                if [ -e ${CHENGDUSAVEDIR}/${FTPGETFILENAME} ];then
                    i=0
                    echoGoodLog "LOG: ${CHENGDUSAVEDIR}/${FTPGETFILENAME} is exist."
                else
                    runFtpGetLog ${FTPGETFILENAME} ${ALIYUNFTPDIR} ${CHENGDUSAVEDIR}
                    i=`echo $?`
                    x=`expr $x + 1`
                fi
            done
            [ -e ${FTPERRORLOG} ] && rm ${FTPERRORLOG}
        done < ${TEMPCHECKLOGLIST}
        rm ${TEMPCHECKLOGLIST}
        return 0
    }
}

CDLOGBACKUPDIR='/data/log_backup'
checkLogFile(){
    DIR=$1
    matchLogName ${DIR}
    ssh -p 22000 upload@'iamIPaddress' ls ${DIR}/${MATCHLOG} > ${TEMPCHECKLOGLIST}
    NOFILESUM=`grep "No such file or directory" ${TEMPCHECKLOGLIST} |wc -l`
    [ ${NOFILESUM} -eq 0 ] && {
        FILESUM=`cat ${TEMPCHECKLOGLIST} |wc -l`
        [ ${FILESUM} -ge 1 ] && {
            LOGBAKDIR=`echo ${DIR} |sed "s#/home/upload#${CDLOGBACKUPDIR}#g"`
            [ -d ${LOGBAKDIR} ] || mkdir -p ${LOGBAKDIR}
            ALIYUNLOGDIR=`echo ${DIR} |sed "s#/home/upload##g"`
            getLogFileToChengDu ${ALIYUNLOGDIR} ${LOGBAKDIR}
        }
    }
}

excludeCheckDir(){
    DIR=$1    
    TEMPDIR=`echo ${NEED_TO_DONE[@]} |sed "s# #/|/#g"`
    TEMPDIRNUM=`echo "${DIR}" |grep -vE "[A-Z]"|grep -vE "[0-9]{4}(.[0-9]{2}){2}"|grep -E "/${TEMPDIR}/" |wc -l`
    TEMPFINDFILE="/tmp/temp_find_file$$.txt"
    [ -e ${TEMPFINDFILE} ] || touch ${TEMPFINDFILE}
    ssh -p 22000 upload@'iamIPaddress' find ${DIR} -maxdepth 1 -type f -mtime -2 > ${TEMPFINDFILE}
    FILE_NUM=`cat ${TEMPFINDFILE}| grep -Eo "$(echo ${DIR} |awk -F/ '{print $4}')" |wc -l`
    [ ${FILE_NUM} -gt 1 ] && [ ${TEMPDIRNUM} -eq 1 ] && {
        checkLogFile ${DIR}
    }
    [ -f ${TEMPFINDFILE} ] && rm ${TEMPFINDFILE}
    return
}

DIRLISTFILE='uploadDirList.txt'
scp -P 22000 upload@'iamIPaddress':/home/upload/${DIRLISTFILE} /IamUsername/

[ -f /IamUsername/${DIRLISTFILE} ] && {
    TEMPFORNUM=$(wc -l /IamUsername/${DIRLISTFILE})
    for((FORNUM=1;FORNUM<=${TEMPFORNUM};FORNUM++))
    do
        DIRNAME=`sed -n "${FORNUM}p" /IamUsername/${DIRLISTFILE}`
        excludeCheckDir ${DIRNAME}
        echoGoodLog "==========${FORNUM}==========="
    done
    rm /IamUsername/${DIRLISTFILE}
}

sendEmail ${TEMP_EMAIL_FILES}
cleanRunLog ${RUN_LOG}
