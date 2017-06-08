#!/bin/bash
#Auto check log files and notice by email
#By colin
#Revision on 2015-10-29
#
#Useage: ./check_log.sh /home/upload/ 
#说明：若带参数，就检查指定的目录，不带参数就检测DIR_LIST数组里面的目录
#
#Chang Log：
#2015-07-29,函数checkLog增加判断，当该文件夹内的文件数量为0时，不予检测。
#2015-10-29，①新增只检测48小时内的有更新的文件夹；②新增只检测符合规则的文件夹；③新增对需要上传文件的数量判断
#
################################
EMAIL=(
    colin@rockhippo.cn
    chris@rockhippo.cn
)

DIR_LIST=(
    /home/upload/aclog
    /home/upload/eglog
    /home/upload/nginxlog
    /home/upload/mysql
)

CHECK_INTERVAL=3600
CHECK_INTERVAL_1_hour=1
CHECK_INTERVAL_24_hour=24

DIR_LIST_24=(
    mysql
)

NEED_TO_DONE=(
    sd
    hlj
)

TEMP_EMAIL_FILES='/tmp/temp_email_files.txt'
RUN_LOG='/var/log/check_log_run_stats.log'
TEMP_DIR_FILES='/tmp/temp_check_log_dir_list.txt'

[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}
[ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES}

NOW_TIME=`date +%F" "%T`
SYS_TIME=`date -d "${NOW_TIME}" +%s`

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

checkLog(){
    [ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES}
    LAST_FILE_TIME=`ls --full-time -lt |head -2|sed -n 2p |awk '{print $6,$7}'|awk -F. '{print $1}'`
    FILE_TIME=`date -d "${LAST_FILE_TIME}" +%s`
    INTERVAL=`expr ${SYS_TIME} - ${FILE_TIME}`
    INTERVAL_HOUR=`expr ${INTERVAL} / ${CHECK_INTERVAL}`
    TEMP_DIR_LIST_24=`echo ${DIR_LIST_24[@]} |sed "s/ /|/g"`
    TMP_I=`echo ${DIR}|grep -E "${TEMP_DIR_LIST_24}" |wc -l`
    FILE_NUM=`ls -lh ${DIR} |grep "^-"|wc -l`

    [ ${FILE_NUM} -gt 0 ] && {
        #当该文件夹超过48个小时没有上传日志文件的就break
        [ ${INTERVAL_HOUR} -gt 48 ] && break 
        cd ${DIR} && {
            if [ ${TMP_I} -eq 0 ];then
                #两小时内的文件数量，至少有一个文件
                FILE_NUM2=`find . -maxdepth 1 -type f -cmin -120|wc -l`
                #若超过两个小时的时候，会出现找到的文件数为零个
                [ ${FILE_NUM2} -eq 0 ] && FILE_NUM2=1
                FILEEXIST_NUM=`expr ${FILE_NUM2} % 2`
                [ ${FILEEXIST_NUM} -eq 1 ] && {
                    if [ ${INTERVAL_HOUR} -ge ${CHECK_INTERVAL_1_hour} ];then
                        cat >>${TEMP_EMAIL_FILES} <<EOF
DIR: $1 more than ${INTERVAL_HOUR} hour not upload a new log file, Please check!
EOF
                        echoBadLog "$x time, The ${DIR} over ${INTERVAL_HOUR} hour did not create a new log file ..."  
                    else
                        cat >>${TEMP_EMAIL_FILES} <<EOF
DIR: $1 loss some new log files, Please check!
EOF
                        echoBadLog "DIR: $1 loss some new log files, Please check!"  
                    fi
                } 
            else
                #48小时内的文件数量，至少有一个文件
                FILE_NUM2=`find . -maxdepth 1 -type f -ctime -48|wc -l`
                #若超过48个小时的时候，会出现找到的文件数为零个
                [ ${FILE_NUM2} -eq 0 ] && FILE_NUM2=1
                FILEEXIST_NUM=`expr ${FILE_NUM2} % 2`
                [ ${FILEEXIST_NUM} -eq 1 ] && {
                    if [ ${INTERVAL_HOUR} -ge ${CHECK_INTERVAL_24_hour} ];then
                        cat >>${TEMP_EMAIL_FILES} <<EOF
DIR: $1 more than ${INTERVAL_HOUR} hour not upload a new log file, Please check!
EOF
                        echoBadLog "$x time, The ${DIR} over ${INTERVAL_HOUR} hour did not create a new log file ..."  
                    else
                        cat >>${TEMP_EMAIL_FILES} <<EOF
DIR: $1 loss some new log files, Please check!
EOF
                        echoBadLog "DIR: $1 loss some new log files, Please check!"  
                    fi
                }
            fi
        }
    }
}

checkDir(){
    #转换目录路径为小写，并排除有数字的目录，关键词在数组NEED_TO_DONE中的目录
    TEMPDIR=`echo ${NEED_TO_DONE[@]} |sed "s# #/|/#g"`
    TEMPDIRNUM=`echo "$1" |tr '[A-Z]' '[a-z]'|grep -v [0-9] |grep -E "/${TEMPDIR}/" |wc -l`
    [ ${TEMPDIRNUM} -eq 1 ] && DIR=$1 || break    
    LAST_LOG_TIME=`tail -500 ${RUN_LOG} |grep ${DIR} |tail -1|awk '''{print $1" "$2}'''`
    log_time=`date -d "${LAST_LOG_TIME}" +%s`
    LOG_INTERVAL=`expr ${SYS_TIME} - ${log_time}`
    x=`tail -500 ${RUN_LOG} |grep ${DIR} |tail -1|awk '{print $3}'`
    [ -z $x ] && x=0
    cd ${DIR}
    if [ "${LOG_INTERVAL}" -ge ${CHECK_INTERVAL} ];then
        [ $x -eq 3 ] && x=1 || i=`expr $x + 1`
        checkLog ${DIR}
    else
        [ "$x" -lt 3 ] && {
            [ $x -eq 3 ] && x=1 || i=`expr $x + 1`;
            checkLog ${DIR} 
        }
    fi
}

loopDir(){
    for i in $1/*
    do
        if [ -d $i ];then
            echo $i >>${TEMP_DIR_FILES}
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
        checkDir $line
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
[ -f ${TEMP_DIR_FILES} ] && rm -rf ${TEMP_DIR_FILES} 
echo "`date +%F" "%T` done." >> ${RUN_LOG}

#清理脚本运行日志记录
TEMP_WC=`cat ${RUN_LOG} |wc -l`
if [ "${TEMP_WC}" -gt 10000 ];then
    sed -i "1,5000d" ${RUN_LOG}
    echoGoodLog "Clean up the ${RUN_LOG}..."
    echoGoodLog "Script: $0 run done."
else
    echoGoodLog "Script: $0 run done."
    exit
fi





