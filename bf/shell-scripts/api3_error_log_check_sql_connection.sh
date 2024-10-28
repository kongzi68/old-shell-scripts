#!/bin/bash
# by colin on 2022-09-13
# revision on 2022-09-13
##################################
##脚本功能：
# 筛选api3的错误日志中mysql连接失败关键词
#
##脚本说明：
#+ 定时计划任务，主要脚本的日志名称格式为：脚本名称.log
#+ 取值于 RUN_LOG="logs/$(basename $0 .sh).log"
# */5 * * * * cd /home/iamUserName/script/shell-scripts && bash api3_error_log_check_sql_connection.sh >> logs/api3_error_log_check_sql_connection.log 2>&1 &
#


## 导入公共函数库，比如：echoGoodLog、echoBadLog等
. /home/iamUserName/script/ops-libs/script-libs/functions.sh

## 日志名称为：脚本名称.log
RUN_LOG="$(pwd)/logs/$(basename $0 .sh).log"
[[ ! -f ${RUN_LOG} ]] && touch ${RUN_LOG}
echoGoodLog "Now, Script: $(basename $0) running."

## 日志时间告警阈值，整数，单位分钟，如下表示5分钟
ALARM_THRESHOLD=5
GREP_KEYS=$(date -d "-${ALARM_THRESHOLD} min" '+%F %H:%M')
echoGoodLog "5分钟前时间字符串：$GREP_KEYS"

## 查询最近5分钟内的api3报错日志，统计日志报错关键词数量
LOG_DIR='/data2t/iamUserName/projects/bar/log/bar-svc-api-app'
cd "${LOG_DIR}" && {
    ERROR_KEYS_COUNT=$(grep -A 10000 "${GREP_KEYS}" bar-svc-api-app-error.log | grep -i "connection is not available" | tail -1 | wc -l)
} || exit

if [[ $ERROR_KEYS_COUNT -gt 0 ]];then
    echoBadLog "截取到的错误日志关键词 connection is not available，统计数量为：$ERROR_KEYS_COUNT"
    SVC_IP=$(ip addr list eth0 | grep -w inet | awk -F'[[:space:]]+|/' '{print $3}')
    # 发邮件
    python3 /home/iamUserName/script/ops-libs/alarm/ops_alarm.py email -r 李四 \
        -s "api3数据库连接不可用" -c "$(date +%F" "%T":"%N)，hwcapi3 ${SVC_IP} 日志bar-svc-api-app-error.log，截取到5分钟内报错日志关键词：connection is not available"
fi

# 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."
