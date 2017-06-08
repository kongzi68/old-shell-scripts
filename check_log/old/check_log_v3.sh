#!/bin/bash
#Auto check log files and notice by email
#By colin on 2015-06-25,06-29

#定义数组EMAIL：收取报警邮件的EMAIL地址
EMAIL=(
	colin@rockhippo.cn
)

#定义数组DIR_LIST：指定需要检测的根目录
DIR_LIST=(
	/data
)

#设置检测时间间隔
check_interval=3600
check_interval_1_hour=1
check_interval_24_hour=24

#定义数组DIR_LIST_24:间隔24小时检测一次的日志目录关键词
DIR_LIST_24=(
	qd
)

#定义邮件报警文件与运行日志文件变量
TEMP_EMAIL_FILES='/tmp/temp_email_files.txt'
RUN_LOG='/var/log/check_log_run_stats.log'
TEMP_DIR_FILES='/tmp/temp_check_log_dir_list.txt'

#创建脚本运行日志文件 
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

#初始化邮件报警内容头文件
[ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES} && {
    cat >${TEMP_EMAIL_FILES} <<EOF

************ 上传日志文件失败的站点清单 ************

EOF
}

#取得系统当前时间
NOW_TIME=`date +%F" "%T`
sys_time=`date -d "${NOW_TIME}" +%s`

#函数check_log功能说明
#检查时间间隔内，是否有最新日志文件
#若没有新日志文件，就追加报警记录 
check_log(){
[ ! -f ${TEMP_EMAIL_FILES} ] && touch ${TEMP_EMAIL_FILES}
#取得目录下最新文件的时间戳 
LAST_FILE_TIME=`ls --full-time -lt |head -2|sed -n 2p |awk '{print $6,$7}'|awk -F. '{print $1}'`
#LAST_FILE_TIME=`ls --full-time -lt |tail -1 |awk '{print $6,$7}'|awk -F. '{print $1}'`

#把上面取得的时间转化成秒值
file_time=`date -d "${LAST_FILE_TIME}" +%s`

#获取两者时间间隔差值
interval=`expr ${sys_time} - ${file_time}`
interval_hour=`expr ${interval} / ${check_interval}`

temp_dir_list_24=`echo ${DIR_LIST_24[@]} |sed "s/ /|/g"`
tmp_i=`echo ${DIR}|grep -E "${temp_dir_list_24}" |wc -l`

if [ ${tmp_i} -eq 0 ];then
	[ ${interval_hour} -ge ${check_interval_1_hour} ] && {
		cat >>${TEMP_EMAIL_FILES} <<EOF
在 ${LAST_FILE_TIME} 与 ${NOW_TIME} 期间，目录 $1 超过 ${interval_hour} 小时没有上传新的日志文件，请检查错误！ 
EOF
		echo "`date +%F" "%T` $x time, The ${DIR} over ${interval_hour} \
hour did not create a new log file ..." >> ${RUN_LOG}
	}
else
    [ ${interval_hour} -ge ${check_interval_24_hour} ] && {
        cat >>${TEMP_EMAIL_FILES} <<EOF
在 ${LAST_FILE_TIME} 与 ${NOW_TIME} 期间，目录 $1 超过 ${interval_hour} 小时没有上传新的日志文件，请检查错误！ 
EOF
		echo "`date +%F" "%T` $x time, The ${DIR} over ${interval_hour} \
hour did not create a new log file ..." >> ${RUN_LOG}
	}
fi
}

#函数check_dir功能说明
#变量x是发送邮件的次数，一个小时内只发送三次
#变量LOG_INTERVAL是最后一条已发送邮件的时间戳
#这里通过时间戳与发送次数来进行双重判断
#调用chek_log函数
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

#函数loop_dir功能说明
#使用方法：loop_dir /data
#遍历传递过来的参数下的所有目录，并递归调用
loop_dir(){
for i in $1/*
do
	if [ -d $i ];then
		echo $i >>${TEMP_DIR_FILES}
		loop_dir $i		#调用loop_dir
	fi
done
}

#检测脚本是否有参数
#有参数，就检测指定的目录
#无参数，就检测定义的目录数组DIR_LIST
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

#循环检测临时文件列表
[ -f ${TEMP_EMAIL_FILES} ] && {
while read line
do
	check_dir $line
done < ${TEMP_DIR_FILES}
}

#循环邮件数组清单，发出报警通知 
[ `cat ${TEMP_EMAIL_FILES}|wc -l` -eq 3 ] || { 
for i in ${EMAIL[@]}
do
	dos2unix -k ${TEMP_EMAIL_FILES} 
	mail -s "THE LOG Is NOT EXISTS" ${i} < ${TEMP_EMAIL_FILES}
	echo "`date +%F" "%T` And send email to ${i}, Please check ..." >> ${RUN_LOG}
done
}

#清除旧的邮件报警内容
[ -f ${TEMP_EMAIL_FILES} ] && rm -rf ${TEMP_EMAIL_FILES}
[ -f ${TEMP_DIR_FILES} ] && rm -rf ${TEMP_DIR_FILES} 
