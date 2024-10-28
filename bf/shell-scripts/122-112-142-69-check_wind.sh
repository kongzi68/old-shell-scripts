#!/bin/bash
# by colin on 2022-06-09
# revision on 2022-06-14
##################################
##脚本功能：
# 检查WIND同步数据的客户端运行状态
#
##脚本说明：
#+ 定时计划任务，主要脚本的日志名称格式为：脚本名称.log
#+ 取值于 RUN_LOG="logs/$(basename $0 .sh).log"
# */5 * * * * cd /home/iamUserName/script/shell-scripts && bash ipaddr-check_wind.sh >> logs/ipaddr-check_wind.log 2>&1 &
#
#+ 2022-06-14：增加对错误日志的处理


## 导入公共函数库，比如：echoGoodLog、echoBadLog等
. /home/iamUserName/script/ops-libs/script-libs/functions.sh

## 日志名称为：脚本名称.log
RUN_LOG="$(pwd)/logs/$(basename $0 .sh).log"
[[ ! -f ${RUN_LOG} ]] && touch ${RUN_LOG}
echoGoodLog "Now, Script: $(basename $0) running."

## 日志时间告警阈值，整数，单位分钟，如下表示15分钟
ALARM_THRESHOLD=15
ALARM_THRESHOLD_SEC=$(expr $ALARM_THRESHOLD \* 60)

## 获取WIND客户端的info最新日志时间与日志级别
LOG_DIR='/alidata1/fileSync3.linux_x64/WIND/LOG'
cd "${LOG_DIR}" && {
    NEW_INFO_LOGNAME="$(ls -hrt info.logFile* | tail -1)"
    echoGoodLog "当前最新的日志名称为：${NEW_INFO_LOGNAME}"
    LAST_LOG_INFO="$(tail -500 ${NEW_INFO_LOGNAME} | grep -Ew 'INFO|ERROR' | tail -1)"
    LOGTIME="$(echo ${LAST_LOG_INFO} | awk '{print $1,$2}')"
    LOGLEVEL="$(echo ${LAST_LOG_INFO} | grep -Ewo 'INFO|ERROR')"
    echoGoodLog "Log level: ${LOGLEVEL}, Log time: ${LOGTIME}"
} || exit

LOG_SEC=$(date -d "$LOGTIME" +%s)
NOW_SEC=$(date +%s)
INTERVAL_SEC=$(expr $NOW_SEC - $LOG_SEC)
## 日志级别为ERROR，直接触发告警
#+ 否则，需要根据最新日志的最后一条日志内容时间，超过告警阈值报警
# if [[ $INTERVAL_SEC -gt $ALARM_THRESHOLD_SEC || $LOGLEVEL == 'ERROR' ]];then
if [[ $INTERVAL_SEC -gt $ALARM_THRESHOLD_SEC ]];then
    INTERVAL_MIN="$(expr $INTERVAL_SEC / 60)"
    # if [[ $LOGLEVEL == 'ERROR' ]];then
    #     echoBadLog "WIND客户端日志报错，已超过${INTERVAL_MIN}分钟！！！"
    #     python3 /home/iamUserName/script/ops-libs/alarm/ops_alarm.py email -r 李四,张三 \
    #         -s "WIND客户端程序报错" -c "$(date +%F" "%T":"%N)，hwc wind-server WIND客户端日志报错，已超过${INTERVAL_MIN}分钟！！！"
    #     python3 /home/iamUserName/script/ops-libs/alarm/ops_alarm.py call -r 李四 -str 万得日志报错
    # elif [[ $LOGLEVEL == 'INFO' ]];then
    if [[ $LOGLEVEL == 'INFO' ]];then
        echoBadLog "超过${INTERVAL_MIN}分钟，WIND客户端未生成新的运行日志。"
        # 发邮件
        python3 /home/iamUserName/script/ops-libs/alarm/ops_alarm.py email -r 李四,张三 \
            -s "WIND客户端程序未运行" -c "$(date +%F" "%T":"%N)，hwc wind-server WIND客户端超过${INTERVAL_MIN}分钟未生成新的运行日志"
        # 打电话
        python3 /home/iamUserName/script/ops-libs/alarm/ops_alarm.py call -r 李四 -str 万得没有新日志
    fi
fi

# 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."
