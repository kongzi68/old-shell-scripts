#!/bin/bash
# by colin on 2023-06-16
# revision on 2023-06-22
##################################
##脚本功能：
# zjt项目，服务每日重启
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


## 定义Portainer
PORTAINER_URL='https://iamIPaddress:9443'
X_API_KEY='iamSecrets121364964674646161'

## 获取容器id
#+ bar-svc-api-app|data-generator
getSVCContainerID() {
    GREP_KEY="${1?'需要指定服务名称的关键词，给grep筛选容器ID使用。'}"
    CONTAINER_ID="""$(http --verify no --timeout=5 GET ${PORTAINER_URL}/api/endpoints/2/docker/containers/json \
        X-API-Key:"${X_API_KEY}" all==true \
        | jq -r ".[] | select(.Names[]|test(\"${GREP_KEY}\")) | .Id")"""
    #+ 函数返回获取到的容器ID
    [ -n "${CONTAINER_ID}" ] && echo "${CONTAINER_ID}" || echo 'null'
}


## 重启指定ID的容器，并返回重启时的时间
restartContainerByID() {
    CONTAINER_ID=$1
    http --verify no --check-status --ignore-stdin --timeout=5 \
        POST ${PORTAINER_URL}/api/endpoints/2/docker/containers/${CONTAINER_ID}/restart X-API-Key:"${X_API_KEY}" &> /dev/null
    #+ 这里无论容器是否启动成功，都需要返回当前时间用于筛选日志
    echo "$(date +%s)"
}


## 通过容器日志关键词判断服务状态
#+ 循环查询6次，每次间隔60秒，累计等待服务启动6分钟
getLogCheckSVCStatus() {
    CONTAINER_ID=$1
    SVC_NAME_KEY=$2
    SVC_START_TIME="$(date -d @$3 +%F' '%H':'%M)"
    for a in $(seq 1 10);do
        sleep 30   #+ 等待30秒后检查日志
        #+ 用--since查询不出来，用--tail取日志，经统计5M的日志文件，约22000行左右
        #+ 从35000行日志里面，筛选启动时刻之后的10000日志，再从这个10000里面查找启动成功的关键词
        docker container logs --tail 15000 "${CONTAINER_ID}" | grep -A 10000 "${SVC_START_TIME}" | grep -Ewo "Hi.*I'm ready"
        if [ $? -eq 0 ];then
            echoGoodLog "服务：${SVC_NAME_KEY} 重启成功."
            break
        else
            echoBadLog "服务：${SVC_NAME_KEY} 第 ${a} 次检查日志..."
            if [ $a -eq 10 ]; then
                echoBadLog "服务：${SVC_NAME_KEY} 启动失败，日志未查询到关键词: Hi ... I'm ready"
                return 1
            fi
        fi
    done
}


TEMP_MAIL_CONTENT_FILE='/tmp/tmp_restart_svc_docker.txt'
[ -f "${TEMP_MAIL_CONTENT_FILE}" ] || touch "${TEMP_MAIL_CONTENT_FILE}"


## 主函数，串联单个服务的重启逻辑
shellMain() {
    SVC_NAME_KEY="${1?'需要指定服务名称的关键词，给grep筛选容器ID使用。'}"
    CHECK_METHOD="${2?'必须指定检查方法'}"
    SVC_CONTAINER_ID="$(getSVCContainerID ${SVC_NAME_KEY})"
    [ "${SVC_CONTAINER_ID}" = 'null' ] && {
        echoBadLog "指定需要筛选的服务 ${SVC_NAME_KEY} 名称关键词有误..."
        exit
    }
    echoGoodLog "${SVC_NAME_KEY}, ${SVC_CONTAINER_ID}"
    SVC_START_TIME="$(restartContainerByID ${SVC_CONTAINER_ID})"
    # getLogCheckSVCStatus "${SVC_CONTAINER_ID}" ${SVC_NAME_KEY} "${SVC_START_TIME}"
    eval "${CHECK_METHOD}"
    [ $? -eq 1 ] && echo ${SVC_NAME_KEY} >> "${TEMP_MAIL_CONTENT_FILE}"
}


## 重启服务 bar-svc-api-app
SVC_NAME_KEY='bar-svc-api-app'
CHECK_METHOD='getLogCheckSVCStatus ${SVC_CONTAINER_ID} ${SVC_NAME_KEY} ${SVC_START_TIME}'
shellMain "${SVC_NAME_KEY}" "${CHECK_METHOD}"

## 重启服务 data-generator
SVC_NAME_KEY='data-generator'
CHECK_METHOD='getLogCheckSVCStatus ${SVC_CONTAINER_ID} ${SVC_NAME_KEY} ${SVC_START_TIME}'
shellMain "${SVC_NAME_KEY}" "${CHECK_METHOD}"


## 发送邮件与告警
[ -e "${TEMP_MAIL_CONTENT_FILE}" -a -s "${TEMP_MAIL_CONTENT_FILE}" ] && {
    RESTART_SVC_LIST="$(cat ${TEMP_MAIL_CONTENT_FILE} | xargs)"
    rm -f "${TEMP_MAIL_CONTENT_FILE}"
    ALARM_MSG=$(alarmMsgTemplate '告警' '服务重启失败' "zjt prod 服务重启失败清单：${RESTART_SVC_LIST}")
    sendEmail '张三' 'zjt prod 服务重启失败' "${ALARM_MSG}"
    sendMessage '张三' "${ALARM_MSG}"
}

# 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."
