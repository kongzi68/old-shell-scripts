#!/bin/bash
#Auto check log files and notice by email
#By colin
#Revision on 2015-11-03
#
#Useage: ./check_log.sh /home/upload/ 
# 10 * * * * /IamUsername/check_log.sh
#
################################

RUN_LOG='/var/log/check_log_run_stats.log'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoGoodLog "Now, Script: `basename $0` run."
#########################

EMAIL=(
    colin@rockhippo.cn
)

#需要检查的目录
DIR_LIST=(
    /home/upload/aclog
    /home/upload/eglog
    /home/upload/nginxlog
    /home/upload/mysql
    /home/upload/gonet
)

#需要检测的目录应包含的关键词
LOGFILE_TYPE=(
    aclog
    eglog
    nginxlog
    gonet
    mysql
)

#需要检查的省份
NEED_TO_DONE=(
    sd
    hlj
)

CHECK_INTERVAL=3600
CHECK_INTERVAL_1_hour=1
CHECK_INTERVAL_24_hour=24

#24小时检测一次的清单
DIR_LIST_24=(
    mysql
    gonet
)

#在指定时间段内不检查的目录
EXCLUDE_DIR=(
    gonet
)

TEMP_DIR_FILES='/tmp/temp_check_log_dir_list.txt'
TEMP_EMAIL_FILES='/tmp/temp_email_files.txt'
[ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES}

NOW_TIME=`date +%F" "%T`
SYS_TIME=`date -d "${NOW_TIME}" +%s`
HOURTIME=`echo $(date +%k) |sed 's/ //g'`

toDoneGrep(){
    DIR=$1
    LOGFILE_TYPE_TMP=`echo ${LOGFILE_TYPE[@]} |sed "s/ /|/g"`
    CASECONDITION=`echo ${DIR} |grep -Eo "${LOGFILE_TYPE_TMP}"|tail -1`
    case ${CASECONDITION} in
        aclog)GREPCONDITION='[a-z]{5}[0-9]{4}(-[0-9]{2}){3}';;
        eglog)GREPCONDITION='[a-z]{7}[0-9]{4}(-[0-9]{2}){3}';;
        nginxlog)GREPCONDITION='[0-9]{4}(-[0-9]{2}){3}.[a-z]+[0-9]*.nginxlog.tar.gz';;
        gonet)GREPCONDITION='gonet[0-9]{4}(-[0-9]{2}){2}.tar.gz';;
        mysql)GREPCONDITION='[0-9]{4}(-[0-9]{2}){2}.rht_[a-zA-Z]+.tar.gz';;
    esac
}

addToEmail(){
    DIR=$1
    [ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES}   
    [ $4 -eq 1 ] && {
        if [ $2 -ge $3 ];then
            cat >>${TEMP_EMAIL_FILES} <<EOF
DIR: $1 more than ${INTERVAL_HOUR} hour not upload a new log file, Please check!
EOF
            echoBadLog "$x time, The ${DIR} over $2 hour did not create a new log file ..."  
        elif [ $5 -lt $6 ];then
            cat >>${TEMP_EMAIL_FILES} <<EOF
DIR: $1 loss some new log files, Please check!
EOF
            echoBadLog "DIR: ${DIR} loss some new log files, Please check!"  
        fi
    } 
}

checkLog(){
    DIR=$1
    LAST_FILE_TIME=`ls --full-time -lt |head -2|sed -n 2p |awk '{print $6,$7}'|awk -F. '{print $1}'`
    FILE_TIME=`date -d "${LAST_FILE_TIME}" +%s`
    INTERVAL=`expr ${SYS_TIME} - ${FILE_TIME}`
    INTERVAL_HOUR=`expr ${INTERVAL} / ${CHECK_INTERVAL}`    
    TEMP_DIR_LIST_24=`echo ${DIR_LIST_24[@]} |sed "s/ /|/g"`
    TMP_I=`echo ${DIR} |grep -E "${TEMP_DIR_LIST_24}" |wc -l`
    FILE_NUM=`ls -lh ${DIR} |grep "^-"|wc -l`
    [ ${FILE_NUM} -gt 0 ] && [ ${INTERVAL_HOUR} -le 48 ] && {
        cd ${DIR} && {
            if [ ${TMP_I} -eq 0 ];then
                toDoneGrep ${DIR} 
                FILE_NUM2=`find . -maxdepth 1 -type f -mmin -120| grep -Eo "${GREPCONDITION}" |wc -l`
                FILE_NUM3=`find . -maxdepth 1 -type f -mmin -60| grep -Eo "${GREPCONDITION}" |wc -l`
                FILE_NUM_120=`expr ${FILE_NUM2} - ${FILE_NUM3}`
                [ ${FILE_NUM2} -eq 0 ] && FILE_NUM2=1
                FILEEXIST_NUM=`expr ${FILE_NUM2} % 2`
                addToEmail ${DIR} ${INTERVAL_HOUR} ${CHECK_INTERVAL_1_hour} ${FILEEXIST_NUM} ${FILE_NUM3} ${FILE_NUM_120}
            else
                toDoneGrep ${DIR} 
                FILE_NUM2=`find . -maxdepth 1 -type f -mtime -2| grep -Eo "${GREPCONDITION}" |wc -l`
                FILE_NUM3=`find . -maxdepth 1 -type f -mtime -1| grep -Eo "${GREPCONDITION}" |wc -l`
                FILE_NUM_120=`expr ${FILE_NUM2} - ${FILE_NUM3}`
                [ ${FILE_NUM2} -eq 0 ] && FILE_NUM2=1
                FILEEXIST_NUM=`expr ${FILE_NUM2} % 2`
                addToEmail ${DIR} ${INTERVAL_HOUR} ${CHECK_INTERVAL_24_hour} ${FILEEXIST_NUM} ${FILE_NUM3} ${FILE_NUM_120}
            fi
        }
    }
}

checkDir(){
    TEMPDIR=`echo ${NEED_TO_DONE[@]} |sed "s# #/|/#g"`
    TEMPDIRNUM=`echo "${DIR}" |grep -vE "[A-Z]"|grep -vE "[0-9]{4}(.[0-9]{2}){2}"|grep -vE "/[0-9]+"|grep -E "/${TEMPDIR}/" |wc -l`
    [ "${TEMPDIRNUM}" -eq 1 ] && {
        DIR=$1
        LAST_LOG_TIME=`tail -500 ${RUN_LOG} |grep ${DIR} |tail -1|grep -Eo "[0-9]{4}(-[0-9]{2}){2} ([0-9]{2}:){2}[0-9]{2}"`
        [ -z "${LAST_LOG_TIME}" ] && LAST_LOG_TIME=`date +%F" "%T` 
        log_time=`date -d "${LAST_LOG_TIME}" +%s`
        LOG_INTERVAL=`expr ${SYS_TIME} - ${log_time}`
        x=`tail -500 ${RUN_LOG} |grep ${DIR}|grep "time" |tail -1|awk '{print $3}'`
        [ -z "$x" ] && x=0
        cd ${DIR}
        if [ "${LOG_INTERVAL}" -ge "${CHECK_INTERVAL}" ];then
            [ "$x" -eq 3 ] && x=1 || i=`expr $x + 1`
            checkLog ${DIR}
        else
            [ "$x" -lt 3 ] && {
                [ "$x" -eq 3 ] && x=1 || i=`expr $x + 1`;
                checkLog ${DIR}
            }
        fi
    }
}

excludeCheckDir(){
    DIR=$1
    EXCLUDECONDITION=`echo "${DIR}" |awk -F/ '{print $NF}'`
    TEMPNUM=`echo "${EXCLUDE_DIR[@]}" |grep -wo "${EXCLUDECONDITION}" |wc -l`
    if [ "${TEMPNUM}" -ne 1 ];then
        checkDir ${DIR}
    #elif [ "${HOURTIME}" -ge 8 -a "${HOURTIME}" -le 22 ];then
    elif [ "${HOURTIME}" -ge 8 -a "${HOURTIME}" -le 8 ];then
        checkDir ${DIR}
    fi
}

loopDir(){
    for i in $1/*
    do
        if [ -d $i ];then
            TEMPDIR=`echo ${NEED_TO_DONE[@]} |sed "s# #/|/#g"`
            TEMPDIRNUM=`echo "$i" |grep -vE "[A-Z]"|grep -vE "[0-9]{4}(.[0-9]{2}){2}"|grep -E "/${TEMPDIR}/" |wc -l`
            [ ${TEMPDIRNUM} -eq 1 ] && echo "$i" >>${TEMP_DIR_FILES}
            loopDir $i
        fi
    done
}

if [ -z "$*" ];then
    for i in ${DIR_LIST[@]}
    do
        echo `echo "$i" |sed 's#/$##g'` >>${TEMP_DIR_FILES}
        loopDir `echo "$i" |sed 's#/$##g'`
    done
else
    for i in $*
    do
        [ -d $i ] && {
            echo `echo "$i" |sed 's#/$##g'` >>${TEMP_DIR_FILES}
            loopDir `echo "$i" |sed 's#/$##g'` 
            } || echoBadLog "The $i is't a directory, Please check the arguments ..."
    done
fi

[ -f ${TEMP_EMAIL_FILES} ] && {
    while read line
    do
        excludeCheckDir $line
    done < ${TEMP_DIR_FILES}
}

[ `cat ${TEMP_EMAIL_FILES}|wc -l` -eq 0 ] || { 
    for i in ${EMAIL[@]}
    do
        dos2unix -k ${TEMP_EMAIL_FILES} 
        mail -s "THE LOG Is NOT EXISTS" ${i} < ${TEMP_EMAIL_FILES}
        echoGoodLog "Send email to ${i}, Please check ..."
    done
}

[ -f ${TEMP_EMAIL_FILES} ] && rm -rf ${TEMP_EMAIL_FILES}

[ -f ${TEMP_DIR_FILES} ] && {
    cp -a ${TEMP_DIR_FILES} /home/upload/uploadDirList.txt
    rm -rf ${TEMP_DIR_FILES} 
}

TEMP_WC=`cat ${RUN_LOG} |wc -l`
if [ "${TEMP_WC}" -gt 10000 ];then
    sed -i "1,5000d" ${RUN_LOG}
    echoGoodLog "Clean up the ${RUN_LOG}..."
    echoGoodLog "Script: `basename $0` run done."
else
    echoGoodLog "Script: `basename $0` run done."
    exit
fi
