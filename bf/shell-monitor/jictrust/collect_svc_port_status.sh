#!/bin/bash
# by colin on 2023-06-20
# revision on 2023-06-20
##################################
##脚本功能：
# zjt项目，服务端口检查
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


## 检查服务端口状态
checkSVCPortStatus() {
    SVC_PORT=$1
    SVC_NAME=$2
    SVC_IP=$3
    if nc -vz ${SVC_IP} ${SVC_PORT};then
        echoGoodLog "服务: ${SVC_NAME} 端口 ${SVC_PORT} 通."
    else
        echoBadLog "服务: ${SVC_NAME} 端口 ${SVC_PORT} 检查不通..."
        echo "${SVC_NAME}:${SVC_PORT}" >> "${TEMP_MAIL_CONTENT_FILE}"
    fi
}


## 定义Portainer
PORTAINER_URL='https://iamIPaddress:9443'
X_API_KEY='ptr_CD1WzR7ndBgnA4OzWewkW8ffy+ZE6JOfDSxz8qbsSyM='
# ALL_IP_PORTS=$(sh -c """http --verify no --timeout 5 GET ${PORTAINER_URL}/api/endpoints/2/docker/containers/json all==true \
#     X-API-Key:"${X_API_KEY}" | jq '[.[] | {NAMES: .Names[0], IP: (.NetworkSettings.Networks."new-bar_default".IPAddress, .NetworkSettings.Networks.bridge.IPAddress), PORT: .Ports[].PrivatePort}]' \
#     | jq '[.[] | select(.IP!=null)]'""")

ALL_IP_PORTS="""$(http --verify no --timeout 5 GET ${PORTAINER_URL}/api/endpoints/2/docker/containers/json all==true \
    X-API-Key:"${X_API_KEY}" | jq '[.[] | {NAMES: .Names[0], IP: (.NetworkSettings.Networks."new-bar_default".IPAddress, .NetworkSettings.Networks.bridge.IPAddress), PORT: .Ports[].PrivatePort}]' \
    | jq 'unique' | jq '[.[] | select(.IP!=null)]')"""

JQ_LENGTH=$(echo ${ALL_IP_PORTS} | jq 'length')
for i in $(seq 0 $(expr ${JQ_LENGTH} - 1));do
    NAMES=$(echo ${ALL_IP_PORTS} | jq -r ".[$i] | .NAMES" | awk -F'/' '{print $NF}')
    IP=$(echo ${ALL_IP_PORTS} | jq -r ".[$i] | .IP")
    PORT=$(echo ${ALL_IP_PORTS} | jq ".[$i] | .PORT")
    echoGoodLog "$NAMES, $IP, $PORT"
    checkSVCPortStatus "$PORT" "$NAMES" "$IP" 
done


## 发送邮件与告警
[ -e "${TEMP_MAIL_CONTENT_FILE}" -a -s "${TEMP_MAIL_CONTENT_FILE}" ] && {
    SVC_LISTS="$(cat ${TEMP_MAIL_CONTENT_FILE} | xargs)"
    rm -f "${TEMP_MAIL_CONTENT_FILE}"
    ALARM_MSG=$(alarmMsgTemplate '告警' '服务端口检查不通' "zjt prod 服务端口检查不通清单：${SVC_LISTS}")
    sendEmail '张三' 'zjt prod 服务端口检查不通' "${ALARM_MSG}"
    sendMessage '张三' "${ALARM_MSG}"
}

# 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."
