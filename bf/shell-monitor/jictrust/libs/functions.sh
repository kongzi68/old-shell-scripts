#!/bin/bash
# by colin on 2022-06-09
# revision on 2023-05-22
##################################
##脚本功能：
# 脚本日志公共函数
#
##脚本说明：
# zjt生产环境专用

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin'


## 获取操作系统类型名称，username、centos
OS_TYPE=$(sed -n '/^ID=/p' /etc/os-release | grep -Eo "[a-z]+")
getOsType() {
    echo "${OS_TYPE}"
}


## 输出绿色日志，表成功类型
#+ 使用示例：echoGoodLog "好消息"
echoGoodLog() {
    /bin/echo -e "\033[32m$(date +%F" "%T":"%N)|$(basename $0)|$*\033[0m"
}


## 输出红色日志，表失败类型
#+ 使用示例：echoBadLog "坏消息"
echoBadLog() {
    /bin/echo -e "\033[31m$(date +%F" "%T":"%N)|$(basename $0)|$*\033[0m"
}


## 日志清理
#+ 使用示例：cleanRunLog "$(basename $0 .sh).log"
# 定义常量
RUNLOG_MAX_NUM=100000
RUNLOG_MAX_DELNUM=5000
cleanRunLog() {
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC="$(wc -l ${CLEANLOGFILE} |awk '{print $1}')"
    [[ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ]] && sed -i "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE}
}


## 获取服务器IP地址
getIP() {
    IFACE=$(ip route | head -1 | awk '{print $5}')
    IP=$(ip addr list ${IFACE} | grep -E "${IFACE}\$" | awk -F'[ /]+' '{print $3}')
    echo ${IP}
}


## 获取容器id
#+ 使用示例：getSVCContainerID 容器名称关键词
#+ 比如：getSVCContainerID 'bar-api4-mysql'
getSVCContainerID() {
    GREP_KEY="${1?'需要指定服务名称的关键词，给grep筛选容器ID使用。'}"
    CONTAINER_ID="$(docker container ls | grep ${GREP_KEY} | awk '{print $1}')"
    #+ 函数返回获取到的容器ID
    [ -n "${CONTAINER_ID}" ] && echo "${CONTAINER_ID}" || echo 'null'
}


## 告警发3次，告警收敛
#+ 间隔120分钟后，若未恢复则继续告警
#+ return：0 继续告警，1 收敛告警
alarmConvergence() {
    INTERVAL_TIME=${1:-120}
    LOCK_FILE="/tmp/$(basename $0 .sh).lock"
    UNLOCK_FILE="/tmp/$(basename $0 .sh).unlock"
    [ -f ${UNLOCK_FILE} ] && rm -f "${UNLOCK_FILE}"
    if [ -f ${LOCK_FILE} ];then
        CREATE_TIME=$(cat ${LOCK_FILE} | awk -F'::' '{print $1}')
        TEMP_NUM=$(cat ${LOCK_FILE} | awk -F'::' '{print $2}')
        # 间隔小于 INTERVAL_TIME
        if TEMP_=$(echo "$(date +%s) - ${CREATE_TIME} < ${INTERVAL_TIME} * 60" | bc);[[ ${TEMP_} -eq 1 ]];then
            if [[ ${TEMP_NUM} -lt 3 ]];then
                let "TEMP_NUM+=1"
                echo "${CREATE_TIME}::${TEMP_NUM}" > ${LOCK_FILE}
                return 0
            else
                return 1
            fi
        else
            echo "$(date +%s)::1" > ${LOCK_FILE}
            return 0
        fi
    else
        echo "$(date +%s)::1" > ${LOCK_FILE}
        return 0
    fi
}


## 告警恢复
#+ return：0 发告警通知，1 不告警
alarmRestore() {
    UNLOCK_FILE="/tmp/$(basename $0 .sh).unlock"
    LOCK_FILE="/tmp/$(basename $0 .sh).lock"
    if [ -f ${UNLOCK_FILE} -a ! -f ${LOCK_FILE} ];then
        return 1
    elif [ -f ${UNLOCK_FILE} -a -f ${LOCK_FILE} ];then
        rm -f "${LOCK_FILE}"
        return 1
    elif [ ! -f ${UNLOCK_FILE} -a -f ${LOCK_FILE} ];then
        touch "${UNLOCK_FILE}"
        rm -f "${LOCK_FILE}"
        return 0
    elif [ ! -f ${UNLOCK_FILE} -a ! -f ${LOCK_FILE} ];then
        touch "${UNLOCK_FILE}"
        return 1
    fi
}


## 告警模板
#
#+ ALARM_LEVEL：告警级别
#+ ALARM_TITLE：告警标题
#+ ALARM_INFO：告警内容
#
#+ Usage：alarmMsgTemplate ALARM_LEVEL ALARM_TITLE ALARM_INFO
#+ 使用示例：alarmMsgTemplate 'S1 紧急' '1_loadavg' "1分钟loadavg：${LOADAVG_1}，CPU核数: ${CPU_CORE_NUM}"
alarmMsgTemplate() {
    ALARM_LEVEL="$1"
    ALARM_TITLE="$2"
    ALARM_INFO="$3"
    IFACE=$(ip route | head -1 | awk '{print $5}')
    IPADDRESS=$(ip addr list ${IFACE} | grep -E "${IFACE}$" | awk -F'[ /]+' '{print $3}')
    cat <<EOF
告警级别: ${ALARM_LEVEL}
告警标题: ${ALARM_TITLE}
服务器标识：$(hostname), ${IPADDRESS}
告警内容: ${ALARM_INFO}
触发时间: $(date +%F" "%T)
EOF
}


### 通讯录
## 添加规则：姓名::邮件地址1,邮件地址2，即多个地址用1个英文逗号分隔::手机号码1,手机号码2
ADDRESS_LIST=(
    张三::zhangsan@betack.com::15987654321
    李四::lisi@betack.com,641070994@qq.com::13618049718
)
## 通过传入姓名获取地址
#
#+ NAMES：姓名字符串，必填项，多人用英文逗号分隔
#+ GET_TYPE：email|sms，必填项，默认值email
#
#+ Usage: getAddressByName NAMES GET_TYPE
#+ 使用示例：getAddressByName 张三,李四 sms
getAddressByName() {
    NAMES=$1
    GET_TYPE="${2:-email}"
    RET_ARR=()
    i=0
    for name in $(echo "${NAMES}" | sed 's/,/ /g');do
        for item in ${ADDRESS_LIST[@]};do
            T_NAME=$(echo $item | awk -F'::' '{print $1}')
            T_EMAIL=$(echo $item | awk -F'::' '{print $2}')
            T_PHONE=$(echo $item | awk -F'::' '{print $3}')
            if [ "${name}" == "${T_NAME}" -a "${GET_TYPE}" == 'email' ];then
                RET_ARR[$i]=${T_EMAIL}
                let "i+=1"
                continue
            elif [ "${name}" == "${T_NAME}" -a "${GET_TYPE}" == 'sms' ];then
                RET_ARR[$i]=${T_PHONE}
                let "i+=1"
                continue
            fi
        done
    done
    T_RET_ARR=$(echo ${RET_ARR[@]} | sed 's/ /,/g')
    echo "${T_RET_ARR}"
}


### zjt告警信息发送
## 邮件告警
#
#+ RECEIVERS：email地址，多个接收者用英文逗号分隔，必填项
#+ EMAIL_TITLE：邮件标题，必填项
#+ EMAIL_CONTENT：邮件内容，必填项
#
#+ Usage: sendEmail RECEIVERS EMAIL_TITLE EMAIL_CONTENT
#+ 使用示例：sendEmail 'zhangsan@qq.com,lisi@126.com' '每日数据更新失败' 'zjt生产环境，每日数据更新失败告警，请及时处理。'
TOOLS_IMAGE_TAG='20230506-v1'
CONFIG_DIR='/data/iamUserName/jicSendEmailOrSMS/conf'
sendEmail() {
    RECEIVERS="$(getAddressByName $1)"
    EMAIL_TITLE=$2
    EMAIL_CONTENT=$3
    [ -d ${CONFIG_DIR} ] || mkdir -p ${CONFIG_DIR}
    docker run --rm --name jicSendEmailOrSMS \
    -v /data/iamUserName/jicSendEmailOrSMS/conf:/opt/iamUserName/conf \
    -w /opt/iamUserName \
    harbor.betack.com/jic/jictrust-send-email-or-sms:${TOOLS_IMAGE_TAG} \
    python jicSendEmailOrSMS.py email -r "${RECEIVERS}" -s "${EMAIL_TITLE}" -c "${EMAIL_CONTENT}"
}


## 短信告警
#
#+ RECEIVERS：手机号码，多个接收者用英文逗号分隔，必填项
#+ MESSAGE: 短信内容，，必填项
#
#+ Usage: sendMessage RECEIVERS MESSAGE
#+ 使用示例：sendMessage '15982360120,16782560199' 'zjt生产环境，每日数据更新失败告警，请及时处理。'
sendMessage() {
    RECEIVERS="$(getAddressByName $1 sms)"
    MESSAGE=$2
    [ -d ${CONFIG_DIR} ] || mkdir -p ${CONFIG_DIR}
    docker run --rm --name jicSendEmailOrSMS \
    -v /data/iamUserName/jicSendEmailOrSMS/conf:/opt/iamUserName/conf \
    -w /opt/iamUserName \
    harbor.betack.com/jic/jictrust-send-email-or-sms:${TOOLS_IMAGE_TAG} \
    python jicSendEmailOrSMS.py sms -r "${RECEIVERS}" -m "${MESSAGE}"
}

