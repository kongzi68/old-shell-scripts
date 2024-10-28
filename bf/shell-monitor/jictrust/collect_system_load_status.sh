#!/bin/bash
# by colin on 2023-05-08
# revision on 2023-05-10
##################################
##脚本功能：
# zjt项目，服务器负载监控告警
#+ 增加告警锁，连续发送3次，超过3次后，隔比如180分钟后，若未恢复则继续告警
#+ 增加告警模板
#+ 增加恢复模板
#+ 增加告警级别
#+ 恢复通知
#
##脚本说明：
#+ 定时计划任务，主要脚本的日志名称格式为：脚本名称.log
#+ 取值于 RUN_LOG="logs/$(basename $0 .sh).log"
# */3 * * * * cd SCRIPT_DIR && bash $(basename $0) >> logs/$(basename $0 .sh).log 2>&1 &
#

## 定义脚本所在路径
#+ 所有脚本都在这个目录下
SCRIPT_DIR='/home/iamUserName/scripts/monitor'

## 导入公共函数库，比如：echoGoodLog、echoBadLog等
. "${SCRIPT_DIR}/libs/functions.sh"

## 日志名称为：脚本名称.log
LOG_DIR="${SCRIPT_DIR}/logs"
RUN_LOG="${LOG_DIR}/$(basename $0 .sh).log"
[ -d ${LOG_DIR} ] || mkdir -p ${LOG_DIR}
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}
echoGoodLog "Now, Script: $(basename $0) running."

## 服务器负载采集
CPU_CORE_NUM=$(nproc)
LOADAVG_1=$(cat /proc/loadavg | awk '{print $1}')
#+ S1告警
if TEMP_=$(echo "${LOADAVG_1} >= ${CPU_CORE_NUM}" | bc);[[ ${TEMP_} -eq 1 ]];then
    echoBadLog "cpu loadavg: ${LOADAVG_1}"
    if alarmConvergence;then
        echoGoodLog "发送告警信息"
        ALARM_MSG=$(alarmMsgTemplate 'S1 紧急' '1_loadavg' "1分钟loadavg：${LOADAVG_1}，CPU核数: ${CPU_CORE_NUM}")
        sendEmail '张三' 'zjtprod cpu负载超高告警' "${ALARM_MSG}"
        sendMessage '张三' "${ALARM_MSG}"
    else
        echoGoodLog "收敛告警信息"
    fi
#+ S2告警
elif TEMP_=$(echo "${LOADAVG_1} >= $(expr ${CPU_CORE_NUM} / 2)" | bc);[[ ${TEMP_} -eq 1 ]];then
    echoBadLog "cpu loadavg: ${LOADAVG_1}"
    if alarmConvergence;then
        echoGoodLog "发送告警信息"
        ALARM_MSG=$(alarmMsgTemplate 'S2 提醒' '1_loadavg' "1分钟loadavg：${LOADAVG_1}，CPU核数: ${CPU_CORE_NUM}")
        sendEmail '张三' 'zjtprod cpu负载告警' "${ALARM_MSG}"
        sendMessage '张三' "${ALARM_MSG}"
    else
        echoGoodLog "收敛告警信息"
    fi
#+ 告警恢复
elif TEMP_=$(echo "${LOADAVG_1} <= $(expr ${CPU_CORE_NUM} / 10)" | bc);[[ ${TEMP_} -eq 1 ]];then
    if alarmRestore;then
        echoGoodLog "cpu loadavg: ${LOADAVG_1}"
        echoGoodLog "发送恢复信息"
        ALARM_MSG=$(alarmMsgTemplate '恢复正常' '1_loadavg' "1分钟loadavg：${LOADAVG_1}，CPU核数: ${CPU_CORE_NUM}")
        sendEmail '张三' 'zjtprod cpu负载告警恢复' "${ALARM_MSG}"
        sendMessage '张三' "${ALARM_MSG}"
    fi
fi

## 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."