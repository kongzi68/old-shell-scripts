#!/bin/bash
#Auto check log files and notice by email
#By colin on 2015-06-25

# Add email address
EMAIL=(
	colin@rockhippo.cn
	kongzi68@qq.com
)

# Set the check interval, 1 hour = 3600 seconds
check_interval=3600
check_interval_hour=1

TEMP_EMAIL_FILES='/tmp/temp_email_files.txt'
RUN_LOG='/var/log/check_log_run_stats.log'
DIR_LIST='/root/check_log/dir_list.txt'

# Get the time of the system and the timestamp of the last file
NOW_TIME=`date +%F" "%T`
LAST_FILE_TIME=`ls --full-time -lt|head -2|sed -n 2p |awk '{print $6,$7}'|awk -F. '{print $1}'`
#LAST_FILE_TIME=`ls --full-time -lt|tail -1 |awk '{print $6,$7}'|awk -F. '{print $1}'`

# Convert the timestamp to seconds
sys_time=`date -d "${NOW_TIME}" +%s`
file_time=`date -d "${LAST_FILE_TIME}" +%s`
# The D-value
interval=`expr ${sys_time} - ${file_time}`
interval_hour=`expr ${interval} / ${check_interval}`

# Create the run_log for the check_log.sh
if [ ! -f ${RUN_LOG} ];then
	touch ${RUN_LOG}
fi

# Delete the old /tmp/temp_email_files.txt file
#[ -f ${TEMP_EMAIL_FILES} ] && rm -rf ${TEMP_EMAIL_FILES}

# Check the /root/check_log/dir_list.txt
if [ -f ${DIR_LIST} ];then
	if [ "`cat ${DIR_LIST} |wc -l`" -eq 0 ];then
		echo "${NOW_TIME} The ${DIR_LIST} is NULL, Please input DIR_LIST to the ${DIR_LIST}." >> ${RUN_LOG}
		exit
	fi
else
	echo "${NOW_TIME} The ${DIR_LIST} is't exists, Please create it." >> ${RUN_LOG}
fi

# The function to check the log file is or isn't exists
check_log()
{
[ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES}
[ ${interval_hour} -ge ${check_interval_hour} ] && {
	cat >>${TEMP_EMAIL_FILES} <<EOF
*********The log is't exists*********

Alarm type: the log is't exists
Services: check log files
Alarm time: `date`
The DIR: $1
Alarm details:
In the "$1" directory, there is an error, to deal with.
Over ${interval_hour} hour did not create a new log file ...
========================================
EOF
}
}

# The code re-use
call_chek_log()
{
	[ $i -eq 3 ] && i=1 || i=`expr $i + 1`
    check_log ${DIR};   # Call the check_log function
    echo "${NOW_TIME} $i time, The ${DIR} over ${interval_hour} hour did not create a new log file ..." >> ${RUN_LOG} 
}

# Loop the dir_list.txt, To check the log ...
while read line
do
	DIR=`echo ${line}`
	LAST_LOG_TIME=`tail -100 ${RUN_LOG} |grep ${DIR} |tail -1|awk '''{print $1" "$2}'''`
	log_time=`date -d "${LAST_LOG_TIME}" +%s`
	LOG_INTERVAL=`expr ${sys_time} - ${log_time}`
	i=`tail -100 ${RUN_LOG} |grep ${DIR} |tail -1|awk '{print $3}'`
	[ -z $i ] && i=0
	if [ -d ${DIR} ];then 
		cd ${DIR}
		if [ "${LOG_INTERVAL}" -ge ${check_interval} ];then
			call_chek_log
		else 
			[ "$i" -lt 3 ] && call_chek_log
		fi
	else
		echo "${NOW_TIME} The ${DIR} is't exists, Please check the dir_list.txt ..." >> ${RUN_LOG}
	fi
done < ${DIR_LIST}

# Loop the array of the EMAIL, To send mail.
[ `cat ${TEMP_EMAIL_FILES}|wc -l` -eq 0 ] && exit
for i in ${EMAIL[@]}
do
	unix2dos -k ${TEMP_EMAIL_FILES}
	mail -s "THE LOG Is NOT EXISTS" ${i} < ${TEMP_EMAIL_FILES}
	echo "${NOW_TIME} And send email to ${i}, Please check ..." >> ${RUN_LOG}
done

[ -f ${TEMP_EMAIL_FILES} ] && rm -rf ${TEMP_EMAIL_FILES}
