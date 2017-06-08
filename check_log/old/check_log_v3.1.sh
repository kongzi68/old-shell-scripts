#!/bin/bash
#Auto check log files and notice by email
#By colin on 2015-06-25,06-29

EMAIL=(
	colin@rockhippo.cn
	chris@rockhippo.cn
)

DIR_LIST=(
    /data
)

check_interval=3600
check_interval_1_hour=1
check_interval_24_hour=24

DIR_LIST_24=(
	qdb
)

TEMP_EMAIL_FILES='/tmp/temp_email_files.txt'
RUN_LOG='/var/log/check_log_run_stats.log'
TEMP_DIR_FILES='/tmp/temp_check_log_dir_list.txt'

[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

[ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES}

NOW_TIME=`date +%F" "%T`
sys_time=`date -d "${NOW_TIME}" +%s`


check_log(){
[ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES}

LAST_FILE_TIME=`ls --full-time -lt |head -2|sed -n 2p |awk '{print $6,$7}'|awk -F. '{print $1}'`
#LAST_FILE_TIME=`ls --full-time -lt |tail -1 |awk '{print $6,$7}'|awk -F. '{print $1}'`


file_time=`date -d "${LAST_FILE_TIME}" +%s`

interval=`expr ${sys_time} - ${file_time}`
interval_hour=`expr ${interval} / ${check_interval}`

temp_dir_list_24=`echo ${DIR_LIST_24[@]} |sed "s/ /|/g"`
tmp_i=`echo ${DIR}|grep -E "${temp_dir_list_24}" |wc -l`

if [ ${tmp_i} -eq 0 ];then
	[ ${interval_hour} -ge ${check_interval_1_hour} ] && {
		cat >>${TEMP_EMAIL_FILES} <<EOF
DIR: $1 more than ${interval_hour} hour not upload a new log file,please check!
EOF
		echo "`date +%F" "%T` $x time, The ${DIR} over ${interval_hour} \
hour did not create a new log file ..." >> ${RUN_LOG}
	}
else
    [ ${interval_hour} -ge ${check_interval_24_hour} ] && {
        cat >>${TEMP_EMAIL_FILES} <<EOF
DIR: $1 more than ${interval_hour} hour not upload a new log file,please check!
EOF
		echo "`date +%F" "%T` $x time, The ${DIR} over ${interval_hour} \
hour did not create a new log file ..." >> ${RUN_LOG}
	}
fi
}


check_dir(){
DIR=$1
LAST_LOG_TIME=`tail -100 ${RUN_LOG} |grep ${DIR} |tail -1|awk '''{print $1" "$2}'''`
log_time=`date -d "${LAST_LOG_TIME}" +%s`
LOG_INTERVAL=`expr ${sys_time} - ${log_time}`
x=`tail -100 ${RUN_LOG} |grep ${DIR} |tail -1|awk '{print $3}'`
[ -z $x ] && x=0
cd ${DIR}
if [ "${LOG_INTERVAL}" -ge ${check_interval} ];then
	[ $x -eq 3 ] && x=1 || i=`expr $x + 1`
    check_log ${DIR}
else
    [ "$x" -lt 3 ] && {
		[ $x -eq 3 ] && x=1 || i=`expr $x + 1`;
		check_log ${DIR} 
	}
fi
}


loop_dir(){
for i in $1/*
do
	if [ -d $i ];then
		echo $i >>${TEMP_DIR_FILES}
		loop_dir $i
	fi
done
}


if [ -z "$*" ];then
	for i in ${DIR_LIST[@]}
    do
		echo `echo "$i" |sed 's#/$##g'` >>${TEMP_DIR_FILES}
		loop_dir `echo "$i" |sed 's#/$##g'`
    done
else
	for i in $*
	do
		[ -d $i ] && {
			echo `echo "$i" |sed 's#/$##g'` >>${TEMP_DIR_FILES};loop_dir `echo "$i" |sed 's#/$##g'` 
}|| echo "`date +%F" "%T` The $i is't a directory, Please check the arguments ..." >> ${RUN_LOG}
	done
fi

[ -f ${TEMP_EMAIL_FILES} ] && {
while read line
do
	check_dir $line
done < ${TEMP_DIR_FILES}
}

[ `cat ${TEMP_EMAIL_FILES}|wc -l` -eq 3 ] || { 
for i in ${EMAIL[@]}
do
	dos2unix -k ${TEMP_EMAIL_FILES} 
	mail -s "THE LOG Is NOT EXISTS" ${i} < ${TEMP_EMAIL_FILES}
	echo "`date +%F" "%T` And send email to ${i}, Please check ..." >> ${RUN_LOG}
done
}

[ -f ${TEMP_EMAIL_FILES} ] && rm -rf ${TEMP_EMAIL_FILES}
[ -f ${TEMP_DIR_FILES} ] && rm -rf ${TEMP_DIR_FILES} 

