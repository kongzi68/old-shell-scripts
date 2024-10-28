#!/bin/bash
# bak_mysql_db.sh
# by colin on 2023-05-18
# revision on 2023-05-22
##################################
##脚本功能：
# zjt专用：备份 docker 启动的 mysql database
#
##脚本说明：
#+ 增加备份故障邮件报警
#
## 计划任务
#+ 定时计划任务，主要脚本的日志名称格式为：脚本名称.log
#+ 取值于 RUN_LOG="logs/$(basename $0 .sh).log"
#
#+ 默认备份除EXCLUDE_DBNAMES之外的所有库
#+ 5 1 * * * cd SCRIPT_DIR && bash $(basename $0) BAK_DIR CONTAINER_GREP_KEY >> logs/$(basename $0 .sh).log 2>&1 &
#+ 备份指定库
#+ 5 1 * * * cd SCRIPT_DIR && bash $(basename $0) BAK_DIR CONTAINER_GREP_KEY DB_LIST >> logs/$(basename $0 .sh).log 2>&1 &
#
#+ bash bak_mysql_db.sh '/data_bak/prod_138_180/mysql_daily_bak' 'bar-api4-mysql' "new_bar new_common"
#+ 05 01 * * * cd /home/iamUserName/script/shell-scripts && bash bak_mysql_db.sh '/data_bak/prod_138_180/mysql_daily_bak' 'bar-api4-mysql' "bar_subscribe new_bar new_common" >> logs/bak_mysql_db.log 2>&1 &


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

TEMP_MAIL_CONTENT_FILE="$(mktemp /tmp/$(basename $0 .sh).XXXXXXXX)"
[ -f "${TEMP_MAIL_CONTENT_FILE}" ] || touch "${TEMP_MAIL_CONTENT_FILE}"

## 数据库备份
# BAK_DIR='/data_bak/prod_138_180/mysql_daily_bak'
BAK_DIR="${1:?'Please specify the directory where the backup package is stored.'}"
# CONTAINER_GREP_KEY='bar-api4-mysql'
CONTAINER_GREP_KEY="${2:?'Please specify the name of the MySQL container.'}"
cd "${BAK_DIR}" || exit
EXCLUDE_DBNAMES=(
    information_schema
    mysql
    performance_schema
    sys
)
MYSQL_CONTAINER_ID="$(getSVCContainerID ${CONTAINER_GREP_KEY})"
if [[ $MYSQL_CONTAINER_ID == 'null' ]];then
    echoBadLog "通过关键词 ${CONTAINER_GREP_KEY} 未查询到 mysql 容器ID"
    exit
fi

MYSQL_PSW="/IamUsername/my.password"
testFunc() {
    cat <<EOF
[client]
user=IamUsername
password=Iampassword
EOF
}

docker exec ${MYSQL_CONTAINER_ID} sh -c "echo \"$(testFunc)\" > ${MYSQL_PSW}"
#+ 默认备份除EXCLUDE_DBNAMES之外的所有库，若传参$3，则备份传参的库名
DEFAULT_DB_LIST=$(docker exec ${MYSQL_CONTAINER_ID} mysql --defaults-extra-file="${MYSQL_PSW}" -Ne "show databases;")
DB_LIST="${3:-$DEFAULT_DB_LIST}"
#+ for 循环中的 ${DB_LIST} 不能使用双引号包裹
#+ 这种是错误的: for DBNAME in "${DB_LIST}";do
for DBNAME in ${DB_LIST};do
    #+ 注意：若库名含有字符'-'，则判断不准确
    echo ${EXCLUDE_DBNAMES[*]} | grep -wqF $DBNAME || {
        [ -d "${DBNAME}" ] || mkdir "${DBNAME}"
        cd "${DBNAME}" && {
            MYSQLDUMP_ERROR_LOG="${DBNAME}-log-$(date +%Y%m%d%H).log"
            echoGoodLog "Backing up $DBNAME."
            # bak mysql database
            docker exec ${MYSQL_CONTAINER_ID} mysqldump --defaults-extra-file="${MYSQL_PSW}" --opt \
            --single-transaction -R --triggers --add-drop-database --databases "$DBNAME" \
            --log-error="${MYSQLDUMP_ERROR_LOG}" | gzip > "${DBNAME}-$(date +%Y%m%d%H).sql.gz"
            # 判断错误日志，grep 到关键词 mysqldump 表明有错误
            if docker exec ${MYSQL_CONTAINER_ID} grep -v "Warning" "${MYSQLDUMP_ERROR_LOG}" | grep "mysqldump";then
                echo ${DBNAME} >> "${TEMP_MAIL_CONTENT_FILE}"
                echoBadLog "Backup $DBNAME failed, Please check..."
            else
                echoGoodLog "Backup $DBNAME successfully."
            fi
            # 移走日志文件
            docker exec ${MYSQL_CONTAINER_ID} mv -f "${MYSQLDUMP_ERROR_LOG}" /tmp/
            # 清理旧备份，保留7天
            find . -name '*.sql.gz' -ctime '+7' -delete
        }
        cd "${BAK_DIR}"
    }
done

# 清理mysql备份报错日志文件
docker exec ${MYSQL_CONTAINER_ID} sh -c "cd /tmp/ && find . -name '*.log' -ctime '+2' -delete"

## 发送邮件与告警
[ -e "${TEMP_MAIL_CONTENT_FILE}" -a -s "${TEMP_MAIL_CONTENT_FILE}" ] && {
    ERR_LIST="$(cat ${TEMP_MAIL_CONTENT_FILE} | xargs | sed 's/ /、/g')"
    rm -f "${TEMP_MAIL_CONTENT_FILE}"
    ALARM_MSG=$(alarmMsgTemplate 'S2 提醒' 'MYSQL BACKUP ERROR' "数据库备份失败：${ERR_LIST}，库每日备份故障")
    sendEmail '张三' 'zjtprod MYSQL BACKUP ERROR' "${ALARM_MSG}"
    sendMessage '张三' "${ALARM_MSG}"
}

# 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."