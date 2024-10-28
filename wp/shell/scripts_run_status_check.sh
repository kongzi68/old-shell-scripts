#!/bin/bash
# scripts_run_status_check.sh
# by colin on 2016-08-10
# revision on 2016-08-10
##################################
##脚本功能：
# 检查服务进程是否运行，未运行就启动
#
##脚本说明：
# 计划任务
#+ # add by yunwei for monitor service ./statisticsintofile_0_0
#+ * * * * * /IamUsername/test/scripts_run_status_check.sh >> /var/log/scripts_run_status.log 2>&1
#
##更新记录：
#
##################################
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/scripts_run_status.log'
TEMP_FILE="/tmp/temp_statisticsintofile_$$.txt"

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoGoodLog "Now, Script: `basename $0` run."
RUNLOG_MAX_NUM=100000
RUNLOG_MAX_DELNUM=50000

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
# 需要被检测的清单
#
SERVICE_LIST=(
    IOS::/data/server/statisticsintofile_ios
    ANDROID::/data/server/statisticsintofile
)

##
# 循环处理已有的进程信息
#
for PS_PID in $(ps -ef |grep -vE "grep|$(basename $0)" |grep "statisticsintofile_0_0" |awk '{print $2}')
do
    SERVICE_INFO=$(ls -l /proc/${PS_PID} |grep "statisticsintofile" |grep "exe")
    SERVICE_TYPE=$(echo "${SERVICE_INFO}" |awk -F'/' '{print $4}')
    if [[ "${SERVICE_TYPE}" = "statisticsintofile_ios" ]];then
        echo "IOS" >> ${TEMP_FILE}
    elif [[ "${SERVICE_TYPE}" = "statisticsintofile" ]];then
        echo "ANDROID" >> ${TEMP_FILE}
    fi
    echoGoodLog "$(echo "${SERVICE_INFO}" |awk '{print $NF}') is running, Pid is ${PS_PID}."
done

##
# 代码重用
#+ 启动相应的服务
#
codeReuse(){
    [ -d ${SER_DIR} ] && cd ${SER_DIR} && ./statisticsintofile_0_0 -d && echoBadLog "${SER_DIR}/statisticsintofile_0_0 have to restart ... "
    [ $? -eq 0 ] && echoGoodLog "${SER_DIR}/statisticsintofile_0_0 restart success." || echoBadLog "${SER_DIR}/statisticsintofile_0_0 restart failed, Please check ..."
}

##
# 处理临时文件"/tmp/temp_statisticsintofile_$$.txt"
# 循环处理需要运行的程序目录
#
if [ -f ${TEMP_FILE} ];then
    for T_DIR in ${SERVICE_LIST[@]}
    do
        SER_TYPE=$(echo ${T_DIR} | awk -F'::' '{print $1}')
        SER_DIR=$(echo ${T_DIR} | awk -F'::' '{print $2}')
        [ $(grep "${SER_TYPE}" ${TEMP_FILE} |wc -l) -ge 1 ] || {
            codeReuse
        }
    done
    rm -f ${TEMP_FILE}
else
    for T_DIR in ${SERVICE_LIST[@]}
    do
        SER_DIR=$(echo ${T_DIR} | awk -F'::' '{print $2}')
        codeReuse
    done
fi

cleanRunLog ${RUN_LOG}