#!/bin/bash
# by colin on 2023-06-20
# revision on 2023-06-21
##################################
##脚本功能：
# zjt项目，检查容器是否运行
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

## 跳过服务重启时间
#+ 定时 23:00 重启，23:00~23:06 期间跳过检查
if [ $(date +%-k) -eq 23 ];then
    if [ $(date +%-M) -lt 6 ];then
        echoGoodLog "服务定时重启期间，跳过检查状态"
        echoGoodLog "Script: $(basename $0) run done."
        exit 0
    fi
fi

## 告警内容临时文件
TEMP_MAIL_CONTENT_FILE="/tmp/tmp_$(basename $0 .sh).txt"
[ -f "${TEMP_MAIL_CONTENT_FILE}" ] || touch "${TEMP_MAIL_CONTENT_FILE}"


## 定义Portainer
PORTAINER_URL='https://iamIPaddress:9443'
X_API_KEY='ptr_CD1WzR7ndBgnA4OzWewkW8ffy+ZE6JOfDSxz8qbsSyM='
#+ 每7天更新一次容器列表清单/tmp/jictrust_container_list.txt
TEMP_CONTAINER_FILE='/tmp/jictrust_container_list.txt'
if [ -f ${TEMP_CONTAINER_FILE} ];then
    CHANGE_TIME=$(date -d "$(stat ${TEMP_CONTAINER_FILE} | grep Change | awk '{print $2,$3}')" +%s)
    if TEMP_=$(echo "$(date +%s) - ${CHANGE_TIME} >= 7 * 24 * 60 * 60"| bc);[[ ${TEMP_} -eq 1 ]];then
        http --verify no --timeout 60 GET "${PORTAINER_URL}/api/endpoints/2/docker/containers/json" all==true \
            X-API-Key:"${X_API_KEY}" | jq -r '.[] | .Names[0]' > ${TEMP_CONTAINER_FILE}
        echoGoodLog "更新${TEMP_CONTAINER_FILE}"
    fi
else
    http --verify no --timeout 60 GET "${PORTAINER_URL}/api/endpoints/2/docker/containers/json" all==true \
        X-API-Key:"${X_API_KEY}" | jq -r '.[] | .Names[0]' > ${TEMP_CONTAINER_FILE}
    echoGoodLog "更新${TEMP_CONTAINER_FILE}"
fi

while read container_name;do
    sleep 2
    echo "$container_name"
    [ "${container_name}" = '/new-bar-bar-task-data-migration-1' ] && continue
    CONTAINER_NAME=$(echo "${container_name}" | awk -F'/' '{print $NF}')
    CONTAINER_ID=$(curl -s -k --location --globoff \
        "${PORTAINER_URL}/api/endpoints/2/docker/containers/json?filters={%22status%22%3A[%22running%22%2C%22paused%22]%2C%22name%22%3A[%22${container_name}%22]}" \
        --header "X-API-Key: ${X_API_KEY}" | jq -r '.[] | .Id')
    if [ -z "${CONTAINER_ID}" ];then
        echo "容器 ${CONTAINER_NAME} 不存在，请检查!!!"
        echo ${CONTAINER_NAME} >> "${TEMP_MAIL_CONTENT_FILE}"
    else
        echo "容器 ${CONTAINER_NAME} 存在..."
    fi
done < ${TEMP_CONTAINER_FILE}


## 发送邮件与告警
[ -e "${TEMP_MAIL_CONTENT_FILE}" -a -s "${TEMP_MAIL_CONTENT_FILE}" ] && {
    SVC_LISTS="$(cat ${TEMP_MAIL_CONTENT_FILE} | xargs)"
    rm -f "${TEMP_MAIL_CONTENT_FILE}"
    ALARM_MSG=$(alarmMsgTemplate 'P1告警' '服务挂了' "zjt prod 服务挂了：${SVC_LISTS}")
    sendEmail '张三' 'zjt prod 服务挂了' "${ALARM_MSG}"
    sendMessage '张三' "${ALARM_MSG}"
}

# 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."
