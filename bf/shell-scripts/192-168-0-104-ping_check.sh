#!/bin/bash
# by colin on 2022-05-11
## iamIPaddress这台机子，总是网络不通
#+ 暂时发现通过重启网卡en0后，网络恢复
#+ 用此脚本定时计划，每分钟跑一次
#+ * * * * * sh /var/IamUsername/scripts/ping_check.sh >> /tmp/ping_check_log.txt 2>&1

PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

RUN_LOG='/tmp/ping_check_log.txt'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

echoGoodLog() {
    echo "\033[32m$(date +%F' '%T) $*\033[0m"
}

echoBadLog() {
    echo "\033[31m$(date +%F' '%T) $*\033[0m"
}


echoGoodLog "Now, Script: `basename $0` run."
SCRIPTS_NAME=$(basename $0)
LOCK_FILE="/tmp/${SCRIPTS_NAME}.lock"

scriptsLock(){
    touch ${LOCK_FILE}
}

scriptsUnlock(){
    rm -f ${LOCK_FILE}
}

# 锁文件存在就退出，不存在就创建锁文件
if [ -f "$LOCK_FILE" ];then
    echoBadLog "${SCRIPTS_NAME} is running." && exit
else
    scriptsLock
fi

# 定义常量
RUNLOG_MAX_NUM=100000
RUNLOG_MAX_DELNUM=5000

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`wc -l ${CLEANLOGFILE} |awk '{print $1}'`
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && {
        sed -i '' "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE} && echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    scriptsUnlock  # 运行结束清理锁文件
    # 清理垃圾文件
    cd /tmp && find . -name "000000000*" -type f -ctime -10 -delete
    echoGoodLog "Script: `basename $0` run done."
    exit
}


if ping -c 2 iamIPaddress;then
    echoGoodLog 'ping ok.'
else
    echoBadLog 'ping failed.'
    ifconfig en0 down
    sleep 5
    if ifconfig en0 up;then
        echoGoodLog 'restart en0 ok...'
    fi
fi

# 清理运行日志记录
cleanRunLog ${RUN_LOG}

