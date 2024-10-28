#!/bin/bash
# by colin on 2023-05-12
# revision on 2023-05-22
##################################
##脚本功能：
# zjt项目，服务器磁盘使用率告警
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

## 服务器磁盘使用情况采集
#+ 需要告警的磁盘分区
ALARM_ARRAY=(
    /
    /home
    /data
)
PARTITION_LIST=($(df -h | awk 'NF>3&&NR>1{sub(/%/,"",$(NF-1));print $NF,$(NF-1)}'))
#+ 测试数据
# PARTITION_LIST=( / 91 /home 15 /data 96 )
TEMP_MAIL_CONTENT_FILE="/tmp/$(basename $0 .sh).temp"
[ -f "${TEMP_MAIL_CONTENT_FILE}" ] || touch "${TEMP_MAIL_CONTENT_FILE}"
[ -f "${TEMP_MAIL_CONTENT_FILE}-bak" ] || touch "${TEMP_MAIL_CONTENT_FILE}-bak"
for (( i=0;i<${#PARTITION_LIST[@]};i+=2 ));do
    # 模仿 python a in b
    DISK_NAME="${PARTITION_LIST[i]}"
    DISK_USAGE="${PARTITION_LIST[((i+1))]}"
    echo ${ALARM_ARRAY[*]} | grep -wqF "${DISK_NAME}" && {
        #+ S1告警
        if TEMP_=$(echo "${DISK_USAGE} >= 98" | bc);[[ ${TEMP_} -eq 1 ]];then
            echoBadLog "Warning!!! ${DISK_NAME} used ${DISK_USAGE}%"
            echo "S1紧急:${DISK_NAME}:${DISK_USAGE}%" >> "${TEMP_MAIL_CONTENT_FILE}"
        #+ S2告警
        elif TEMP_=$(echo "${DISK_USAGE} >= 95" | bc);[[ ${TEMP_} -eq 1 ]];then
            echoBadLog "Please note： ${DISK_NAME} used ${DISK_USAGE}%"
            echo "S2提醒:${DISK_NAME}:${DISK_USAGE}%" >> "${TEMP_MAIL_CONTENT_FILE}"
        #+ 告警恢复
        elif TEMP_=$(echo "${DISK_USAGE} < 95" | bc);[[ ${TEMP_} -eq 1 ]];then
            # TODO(colin): 磁盘告警恢复逻辑有些冲突，暂时先用着
            while read line;do
                T_ALARM_LEVEL=$(echo $line | awk -F':' '{print $1}')
                T_DISK_NAME=$(echo $line | awk -F':' '{print $2}')
                if [ "${T_DISK_NAME}" != "${DISK_NAME}" ];then
                    continue
                fi
                if [ "${T_ALARM_LEVEL}" == 'S1紧急' -o "${T_ALARM_LEVEL}" == 'S2提醒' ];then
                    if alarmRestore;then
                        echoGoodLog "${DISK_NAME} used ${DISK_USAGE}%"
                        echo "恢复正常:${DISK_NAME}:${DISK_USAGE}%" >> "${TEMP_MAIL_CONTENT_FILE}"
                    fi
                fi
            done < "${TEMP_MAIL_CONTENT_FILE}-bak"
        fi
    }
done


## 发送邮件与告警
[ -e "${TEMP_MAIL_CONTENT_FILE}" -a -s "${TEMP_MAIL_CONTENT_FILE}" ] && {
    ERR_LIST="$(cat ${TEMP_MAIL_CONTENT_FILE} | xargs | sed 's/ /，/g')"
    mv "${TEMP_MAIL_CONTENT_FILE}" "${TEMP_MAIL_CONTENT_FILE}-bak"
    if $(alarmConvergence 720);then
        echoGoodLog "发送告警信息"
        ALARM_MSG=$(alarmMsgTemplate 'S2 提醒' '磁盘使用率百分比告警' "磁盘使用率百分比告警：${ERR_LIST}，请立即处理。")
        sendEmail '张三' 'zjtprod 磁盘使用率百分比告警' "${ALARM_MSG}"
        sendMessage '张三' "${ALARM_MSG}"
    else
        echoGoodLog "收敛告警信息"
    fi
}


## 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."