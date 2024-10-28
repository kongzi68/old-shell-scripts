#!/bin/bash
# by colin on 2022-06-09
# revision on 2022-06-09
##################################
##脚本功能：
# 脚本日志公共函数
#
##脚本说明：

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin'

## 获取操作系统类型名称，username、centos
OS_TYPE=$(sed -n '/^ID=/p' /etc/os-release | grep -Eo "[a-z]+")
getOsType() {
    echo "${OS_TYPE}"
}

## 输出绿色日志，表成功类型
echoGoodLog() {
    /bin/echo -e "\033[32m$(date +%F" "%T":"%N)|$(basename $0)|$*\033[0m"
}

## 输出红色日志，表失败类型
echoBadLog() {
    /bin/echo -e "\033[31m$(date +%F" "%T":"%N)|$(basename $0)|$*\033[0m"
}

## 获取服务器IP地址
getIP() {
    IFACE=$(ip route | head -1 | awk '{print $5}')
    IP=$(ip addr list ${IFACE} | grep -E "${IFACE}\$" | awk -F'[ /]+' '{print $3}')
    echo ${IP}
}


## 日志清理
#+ 使用示例：cleanRunLog "$(basename $0 .sh).log"
# 定义常量
RUNLOG_MAX_NUM=100000
RUNLOG_MAX_DELNUM=5000
cleanRunLog() {
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC="$(wc -l ${CLEANLOGFILE} |awk '{print $1}')"
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && sed -i "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE}
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


## 飞书机器人消息通知
#+ MSG 不能包含空格
#+ 变量必须要用单引号包裹
sendMsgByFeishu() {
    MSG_TITLE=$1
    MSG=$2
    SRC_ADDR=$3
    curl -X POST -H "Content-Type: application/json" \
    -d '{
            "msg_type": "post",
            "content": {
                "post": {
                    "zh_cn": {
                        "title": "'${MSG_TITLE}'",
                        "content": [[
                            {
                                "tag": "text",
                                "text": "服务环境: '${SRC_ADDR}'\n"
                            },
                            {
                                "tag": "text",
                                "text": "消息内容: '${MSG}'\n"
                            },
                            {
                                "tag": "at",
                                "user_id": "iamsecret",
                                "user_name": "张三"
                            }
                        ]]
                    }
                }
            }
        }' \
    https://open.feishu.cn/open-apis/bot/v2/hook/iamsecret
    echo -e '\n'
}




