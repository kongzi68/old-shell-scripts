#!/bin/bash
# bak_mysql_db_to_minio.sh
# by colin on 2024-03-06
# revision on 2024-08-12
##################################
##脚本功能：
# 备份docker启动的mysql database，备份文件存储到minio
#+ 变更：mysql密码文件/IamUsername/my.password改为手动创建，然后用docker cp拷贝到mysql容器里面
#
##脚本说明：
#+ 增加备份故障邮件报警
##特别说明：
#+ --add-drop-database 参数会增加 drop database 语句
#+ --databases 参数会增加 create database 语句 和 use database 语句
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
#+ bash bak_mysql_db_to_minio.sh '/data_bak/prod_138_180/mysql_daily_bak' 'bar-api4-mysql' "new_bar new_common"
#+ bash bak_mysql_db_to_minio.sh '/data2t/backup/mysql_daily_bak' 'r-bar-mysql-1' 'us hk common'
#+ 05 01 * * * cd /home/iamUserName/script/shell-scripts && bash bak_mysql_db_to_minio.sh '/data_bak/prod_138_180/mysql_daily_bak' 'bar-api4-mysql' "bar_subscribe new_bar new_common" >> logs/bak_mysql_db_to_minio.log 2>&1 &
#+ 01 0 * * * cd /home/iamUserName/script/shell-scripts && bash bak_mysql_db_to_minio.sh '/data2t/backup/mysql_daily_bak' 'r-bar-mysql-1' >> logs/bak_mysql_db_to_minio.log 2>&1 &


## 定义脚本所在路径
#+ 所有脚本都在这个目录下
SCRIPT_PUBLIC_DIR='/home/iamUserName/script'
SCRIPT_DIR="${SCRIPT_PUBLIC_DIR}/shell-scripts"

## 导入公共函数库，比如：echoGoodLog、echoBadLog等
. "${SCRIPT_PUBLIC_DIR}/ops-libs/script-libs/functions.sh"

## 日志名称为：脚本名称.log
LOG_DIR="${SCRIPT_DIR}/logs"
RUN_LOG="${LOG_DIR}/$(basename $0 .sh).log"
[ -d ${LOG_DIR} ] || mkdir -p ${LOG_DIR}
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}
echoGoodLog "Now, Script: $(basename $0) running."

## 发邮件与打电话告警
IPADDR="$(getIP)"
alarmMailAndPhone() {
    LIST_KEYS=$1
    # 发邮件
    python3 ${SCRIPT_PUBLIC_DIR}/ops-libs/alarm/ops_alarm.py email -r 张三 \
        -s "服务器${IPADDR}: MYSQL BACKUP ERROR" -c "$(date +%F" "%T":"%N)，服务器${IPADDR}，${LIST_KEYS}，库每日备份故障"
}

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
LOCAL_MYSQL_PSW="$HOME/.my.password"
[ -e "${LOCAL_MYSQL_PSW}" ] || {
    echoBadLog "mysql 用户名与密码文件不存在，请创建文件：${LOCAL_MYSQL_PSW}，格式如下："
    echoBadLog "[client]\nuser=username\npassword=password"
    exit
}

## minio-client 容器内挂载路径
TEMP_IPADDR=$(echo ${IPADDR} | sed 's/\./-/g')
MINIO_CLIENT_WORKDIR='/opt/bitnami/minio-client'
MINIO_CLIENT_IMAGES='iamIPaddress/libs/minio-client:2024.3.3-v1-sh'
MINIO_STORAGE_BUCKETS_PATH="bfsh-minio/iamUserName-bak/${TEMP_IPADDR}/mysql_daily_bak/"
#+ 登录harbor
docker login -u bfops -p GDXMTW7mTh6g2wu iamIPaddress

#+ mysql密码文件
docker cp ${LOCAL_MYSQL_PSW} ${MYSQL_CONTAINER_ID}:${MYSQL_PSW}
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
            BAK_PKG_NAME="${DBNAME}-$(date +%Y%m%d%H).sql.gz"
            MYSQLDUMP_ERROR_LOG="${DBNAME}-log-$(date +%Y%m%d%H).log"
            echoGoodLog "Backing up $DBNAME."
            # bak mysql database
            docker exec ${MYSQL_CONTAINER_ID} mysqldump --defaults-extra-file="${MYSQL_PSW}" --opt \
            --single-transaction --hex-blob -R --triggers --add-drop-database --databases "$DBNAME" \
            --log-error="${MYSQLDUMP_ERROR_LOG}" | gzip > "${BAK_PKG_NAME}"
            # 判断错误日志，grep 到关键词 mysqldump 表明有错误
            if docker exec ${MYSQL_CONTAINER_ID} grep -v "Warning" "${MYSQLDUMP_ERROR_LOG}" | grep "mysqldump";then
                echo ${DBNAME} >> "${TEMP_MAIL_CONTENT_FILE}"
                echoBadLog "Backup $DBNAME failed, Please check..."
            else
                echoGoodLog "Backup $DBNAME successfully."
            fi
            # 移走日志文件
            docker exec ${MYSQL_CONTAINER_ID} mv -f "${MYSQLDUMP_ERROR_LOG}" /tmp/
            # 清理旧备份，保留2天
            find . -name '*.sql.gz' -ctime '+2' -delete
            # 把备份存储到minio
            docker run --rm --name minio-client -v "${BAK_DIR}/${DBNAME}:${MINIO_CLIENT_WORKDIR}/backup" ${MINIO_CLIENT_IMAGES} ls -lhR backup
            if docker run --rm --name minio-client -v "${BAK_DIR}/${DBNAME}:${MINIO_CLIENT_WORKDIR}/backup" ${MINIO_CLIENT_IMAGES} mc cp "backup/${BAK_PKG_NAME}" "${MINIO_STORAGE_BUCKETS_PATH}";then
                echoGoodLog "Backup $DBNAME to minio successfully."
            else
                echoBadLog "Backup $DBNAME to minio failed, Please check..."
            fi
        }
        cd "${BAK_DIR}"
    }
done

# 清理minio存储的备份包，只保留7天
docker run --rm --name minio-client ${MINIO_CLIENT_IMAGES} mc rm -r --force "${MINIO_STORAGE_BUCKETS_PATH}" --older-than "7d"
# 清理mysql备份报错日志文件
docker exec ${MYSQL_CONTAINER_ID} sh -c "cd /tmp/ && find . -name '*.log' -ctime '+2' -delete"

## 发送邮件与告警
[ -e "${TEMP_MAIL_CONTENT_FILE}" -a -s "${TEMP_MAIL_CONTENT_FILE}" ] && {
    ERR_LIST="$(cat ${TEMP_MAIL_CONTENT_FILE} | xargs | sed 's/ /、/g')"
    rm -f "${TEMP_MAIL_CONTENT_FILE}"
    alarmMailAndPhone "${ERR_LIST}"
    sendMsgByFeishu "MYSQL BACKUP ERROR" "${ERR_LIST}" "${IPADDR}"
}

# 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."