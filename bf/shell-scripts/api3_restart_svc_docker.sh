#!/bin/bash
# by colin on 2022-10-31
# revision on 2023-06-22
##################################
##脚本功能：
# hwctgty，重启docker rancher1.6版部署的服务
#
##脚本说明：
#+ 定时计划任务，主要脚本的日志名称格式为：脚本名称.log
#+ 取值于 RUN_LOG="logs/$(basename $0 .sh).log"
# 00 7 * * * cd /home/iamUserName/script/shell-scripts && bash restart_svc_docker.sh >> logs/restart_svc_docker.log 2>&1 &
#

## 导入公共函数库，比如：echoGoodLog、echoBadLog等
. /home/iamUserName/script/ops-libs/script-libs/functions.sh

## 日志名称为：脚本名称.log
RUN_LOG="$(pwd)/logs/$(basename $0 .sh).log"
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}
echoGoodLog "Now, Script: $(basename $0) running."


## 获取容器id
getSVCContainerID() {
    GREP_KEY="${1?'需要指定服务名称的关键词，给grep筛选容器ID使用。'}"
    CONTAINER_ID="$(docker container ls -q --filter name=${GREP_KEY})"
    # CONTAINER_ID="$(docker container ls | grep ${GREP_KEY} | awk '{print $1}')"
    #+ 函数返回获取到的容器ID
    [ -n "${CONTAINER_ID}" ] && echo "${CONTAINER_ID}" || echo 'null'
}


## 重启指定ID的容器，并返回重启时的时间
restartContainerByID() {
    CONTAINER_ID=$1
    docker container restart "${CONTAINER_ID}" > /dev/null
    #+ 这里无论容器是否启动成功，都需要返回当前时间用于筛选日志
    echo "$(date +%s)"
}


## 通过容器日志关键词判断服务状态
#+ 循环查询6次，每次间隔30秒，累计等待服务启动3分钟
getLogCheckSVCStatus() {
    CONTAINER_ID=$1
    SVC_NAME_KEY=$2
    SVC_START_TIME="$(date -d @$3 +%F' '%H':'%M)"
    for a in $(seq 1 6);do
        sleep 30   #+ 等待30秒后检查日志
        #+ 用--since查询不出来，用--tail取日志，经统计5M的日志文件，约22000行左右
        #+ 从35000行日志里面，筛选启动时刻之后的10000日志，再从这个10000里面查找启动成功的关键词
        docker container logs --tail 20000 "${CONTAINER_ID}" | grep -A 10000 "${SVC_START_TIME}" | grep -Ewo "Hi.*I'm ready"
        if [ $? -eq 0 ];then
            echoGoodLog "服务：${SVC_NAME_KEY} 重启成功."
            break
        else
            echoBadLog "服务：${SVC_NAME_KEY} 第 ${a} 次检查日志..."
        fi
    done

    if [ $a -eq 6 ]; then
        echoBadLog "服务：${SVC_NAME_KEY} 启动失败，日志未查询到关键词: Hi ... I'm ready"
        return 1
    else
        return 0
    fi
}


## 检查服务端口状态
checkSVCPortStatus() {
    SVC_PORT=$1
    SVC_NAME_KEY=$2
    sleep 20   #+ 等待20秒后检测端口
    if nc -z iamIPaddress "${SVC_PORT}";then
        echoGoodLog "服务: ${SVC_NAME_KEY} 重启成功."
        return 0
    else
        echoBadLog "服务: ${SVC_NAME_KEY} 端口 ${SVC_PORT} 检查不通..."
        return 1
    fi
}

## 发邮件与打电话告警
alarmMailAndPhone() {
    SVC_NAME_KEY=$1
    # 发邮件
    python3 /home/iamUserName/script/ops-libs/alarm/ops_alarm.py email -r 李四,张三 \
        -s "tgty生产每日服务重启失败" -c "$(date +%F" "%T":"%N)，hwctgty生产环境，每日重启服务${SVC_NAME_KEY}失败，请检查！！！"
    # 打电话
    python3 /home/iamUserName/script/ops-libs/alarm/ops_alarm.py call -r 李四,张三 -str tg每日重启失败
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
    SVC_START_TIME="$(restartContainerByID ${SVC_CONTAINER_ID})"
    # getLogCheckSVCStatus "${SVC_CONTAINER_ID}" ${SVC_NAME_KEY} "${SVC_START_TIME}"
    eval "${CHECK_METHOD}"
    [ $? -eq 1 ] && echo ${SVC_NAME_KEY} >> "${TEMP_MAIL_CONTENT_FILE}"
}


## 重启服务 bar-svc-offline
SVC_NAME_KEY='bar-svc-offline-1'
CHECK_METHOD='getLogCheckSVCStatus ${SVC_CONTAINER_ID} ${SVC_NAME_KEY} ${SVC_START_TIME}'
shellMain "${SVC_NAME_KEY}" "${CHECK_METHOD}"

## 重启服务 bar-svc-api-app
SVC_NAME_KEY='bar-svc-api-app-1'
CHECK_METHOD='getLogCheckSVCStatus ${SVC_CONTAINER_ID} ${SVC_NAME_KEY} ${SVC_START_TIME}'
shellMain "${SVC_NAME_KEY}" "${CHECK_METHOD}"

## 重启服务 bar-nginx 80
SVC_NAME_KEY='bar-nginx-1'
CHECK_METHOD='checkSVCPortStatus 80 ${SVC_NAME_KEY}'
shellMain "${SVC_NAME_KEY}" "${CHECK_METHOD}"


## 检查rancher部署的api固定容器ip+端口
IPADDRS="$(ip addr list eth0 | grep -w inet | awk -F'[[:space:]]+|/' '{print $3}')"
if [ "${IPADDRS}" = 'iamIPaddress' ];then
    BAR_SVC_API_CONTAINER_IP='iamIPaddress'
elif [ "${IPADDRS}" = 'iamIPaddress' ];then
    BAR_SVC_API_CONTAINER_IP='iamIPaddress'
fi

for a in $(seq 1 6);do
    sleep 30   #+ 等待30秒后检查
    nc -z ${BAR_SVC_API_CONTAINER_IP} 80 && nc -z ${BAR_SVC_API_CONTAINER_IP} 9999
    if [ $? -eq 0 ];then
        echoGoodLog "第 ${a} 次探测服务：svc-api-app rancher 固定IP ${BAR_SVC_API_CONTAINER_IP} 的 80、9999 成功."
        break
    else
        echoBadLog "第 ${a} 次探测服务：svc-api-app rancher 固定IP ${BAR_SVC_API_CONTAINER_IP} 的 80、9999 失败......"
    fi
done


## 重启服务 bar-nginx2 81
SVC_NAME_KEY='bar-nginx2-1'
CHECK_METHOD='checkSVCPortStatus 81 ${SVC_NAME_KEY}'
shellMain "${SVC_NAME_KEY}" "${CHECK_METHOD}"


## 发送邮件与告警
[ -e "${TEMP_MAIL_CONTENT_FILE}" -a -s "${TEMP_MAIL_CONTENT_FILE}" ] && {
    RESTART_SVC_LIST="$(cat ${TEMP_MAIL_CONTENT_FILE} | xargs)"
    rm -f "${TEMP_MAIL_CONTENT_FILE}"
    alarmMailAndPhone "${RESTART_SVC_LIST}"
}

# 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."
