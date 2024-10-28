#!/bin/bash
# bak_files_to_minio.sh
# by colin on 2024-03-08
# revision on 2024-07-10
##################################
##脚本功能：
# 备份文件到minio，加--newer-than限制
#
##脚本说明：
#+ sh -x bak_files_to_minio.sh "/home/iamUserName/script/shell-scripts/bak_files_to_minio_list.txt"
#+ 备份文件清单一般放在脚本同级目录下：bak_files_to_minio_list.txt
#+ IamUsername@gitlab:~# cat /home/iamUserName/script/shell-scripts/bak_files_to_minio_list.txt
#+ /data/gitlab/backups
#+ /data/gitlab/config/gitlab.rb
##特别说明：
#+ --newer-than 1d2hh3mm4ss，mc mirror命令加这个参数，只传指定时间内有更新的文件
#+ 需观察是否能缓解minio所在服务器cpu使用率较高的问题
#
## 计划任务
#+ 定时计划任务，主要脚本的日志名称格式为：脚本名称.log
#+ 取值于 RUN_LOG="logs/$(basename $0 .sh).log"
#
#+ 默认指定的文件清单
#+ 5 1 * * * cd SCRIPT_DIR && bash $(basename $0) BAK_LISTS  >> logs/$(basename $0 .sh).log 2>&1 &
#
#+ sh -x bak_files_to_minio.sh "/home/iamUserName/script/shell-scripts/bak_files_to_minio_list.txt"
#+ 30 22 * * * cd /home/iamUserName/script/shell-scripts && bash bak_files_to_minio.sh './bak_files_to_minio_list.txt' >> logs/bak_files_to_minio.log 2>&1 &


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

## 传参$1，传入需要备份的文件、目录清单
BAK_LISTS="${1:?'Please specify the list of files or directories to be backed up.'}"
[ -f "${BAK_LISTS}" ] || {
    echoBadLog "The backup file list: ${BAK_LISTS} does not exist."
    exit
}

## minio-client 容器内挂载路径
IPADDR="$(getIP)"
TEMP_IPADDR=$(echo ${IPADDR} | sed 's/\./-/g')
MINIO_CLIENT_WORKDIR='/opt/bitnami/minio-client'
MINIO_CLIENT_IMAGES='iamIPaddress/libs/minio-client:2024.3.3-v1-sh'
MINIO_STORAGE_BUCKETS_PATH="bfsh-minio/iamUserName-bak/${TEMP_IPADDR}/backup-files/"
NEWER_THAN_VALUES='1d'  #+ 一天内有过更新的文件
#+ 登录harbor
docker login -u bfops -p GDXMTW7mTh6g2wu iamIPaddress

while read need_bak; do
    if [ -d "${need_bak}" ];then
        NEED_BAK_DIR="$(basename ${need_bak})"
        MOUNT_DIR="${need_bak%${NEED_BAK_DIR}}"
        cd "${MOUNT_DIR}" && {
            echoGoodLog "Backing up $need_bak."
            # 把备份存储到minio
            docker run --rm --name minio-client -v "${MOUNT_DIR}:${MINIO_CLIENT_WORKDIR}/backup" ${MINIO_CLIENT_IMAGES} ls -lh backup
            if docker run --rm --name minio-client -v "${MOUNT_DIR}:${MINIO_CLIENT_WORKDIR}/backup" ${MINIO_CLIENT_IMAGES} mc \
                mirror --newer-than "${NEWER_THAN_VALUES}" --retry --preserve --overwrite --remove "/opt/bitnami/minio-client/backup/${NEED_BAK_DIR}" "${MINIO_STORAGE_BUCKETS_PATH}${NEED_BAK_DIR}";then
                echoGoodLog "Backup $need_bak to minio successfully."
            else
                echoBadLog "Backup $need_bak to minio failed, Please check..."
                sendMsgByFeishu "文件备份错误告警" "${need_bak}" "${IPADDR}"
            fi
        }
    elif [ -f "${need_bak}" ];then
        NEED_BAK_FILES="$(basename ${need_bak})"
        MOUNT_DIR="${need_bak%${NEED_BAK_FILES}}"
        cd "${MOUNT_DIR}" && {
            echoGoodLog "Backing up $need_bak."
            # 把备份存储到minio
            docker run --rm --name minio-client -v "${MOUNT_DIR}:${MINIO_CLIENT_WORKDIR}/backup" ${MINIO_CLIENT_IMAGES} ls -lh backup
            if docker run --rm --name minio-client -v "${MOUNT_DIR}:${MINIO_CLIENT_WORKDIR}/backup" ${MINIO_CLIENT_IMAGES} mc \
                cp --newer-than "${NEWER_THAN_VALUES}" -r "/opt/bitnami/minio-client/backup/${NEED_BAK_FILES}" "${MINIO_STORAGE_BUCKETS_PATH}";then
                echoGoodLog "Backup $need_bak to minio successfully."
            else
                echoBadLog "Backup $need_bak to minio failed, Please check..."
                sendMsgByFeishu "文件备份错误告警" "${need_bak}" "${IPADDR}"
            fi
        }
    fi
done < "${BAK_LISTS}" 

# 清理脚本运行的日志文件
cleanRunLog ${RUN_LOG} && echoGoodLog "Clean up the ${RUN_LOG}."
echoGoodLog "Script: $(basename $0) run done."