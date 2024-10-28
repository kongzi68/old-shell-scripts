#!/bin/bash
# bak_mysql.sh
# by colin on 2017-03-28
# revision on 2017-04-01
##################################
##脚本功能：
# 备份数据库
#
##脚本说明：
# 00 03 * * * /data/script/bak_mysql.sh > /dev/null 2>&1
#
##功能要求：
# 数据库备份
# 对命令执行成功与否进行验证
# 执行失败的发邮件进行通知
# 日志记录
# 运行保护锁

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/cron_scripts_run.log'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}
# 发邮件用的临时文件
EMAIL_FILE='/tmp/bak_mysql_email.txt'
[ ! -f ${EMAIL_FILE} ] && touch ${EMAIL_FILE}

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
    echo "`date +%F" "%T":"%N` $*" >> ${EMAIL_FILE}
}

echoGoodLog "Now, Script: `basename $0` run."

SCRIPTS_NAME=$(basename $0)
LOCK_FILE="/tmp/${SCRIPTS_NAME}.lock"

scriptsLock(){
    touch ${LOCK_FILE}
}

scriptsUnlock(){
    rm -f ${LOCK_FILE}
}

# 锁文件存在就退出，不存在就创建锁文件
if [ -f "$LOCK_FILE" ];then
    echoBadLog "${SCRIPTS_NAME} is running." && exit
else
    scriptsLock
fi

# 定义常量
RUNLOG_MAX_NUM=100000
RUNLOG_MAX_DELNUM=5000

BACKPATH='/data/db_backup/bak_mysql/'  # 路径最后一级必须加‘/’
[ -d ${BACKPATH} ] || mkdir -p ${BACKPATH}

USER='IamUsername'
PASSWORD='thisispassword'
T_YMDH=$(date +%y%m%d%H)
KEEPDAY=6
LOGINIP='iamIPaddress'
BAK_NAME="$(date +%y%m%d).tar.gz"
DBLISTS="${BACKPATH}dblists"

# MOD: 修改接收邮件者
EMAILS=(
    zhangsan@windplay.cn
    test1@windplay.cn
)

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`wc -l ${CLEANLOGFILE} |awk '{print $1}'`
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && {
        sed -i "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE} && echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    scriptsUnlock  # 运行结束清理锁文件
    echoGoodLog "Script: `basename $0` run done."
    exit
}

sendEmail(){
    [ $(wc -l ${EMAIL_FILE}|awk '{print $1}') -eq 0 ] || { 
        for email in ${EMAILS[@]};do
            dos2unix -k ${EMAIL_FILE} 
            mail -s "DB BACKUP FAILED" ${email} < ${EMAIL_FILE}
            if [ $? -eq 0 ];then
                echoGoodLog "Send email to ${email} successfully."
            else
                echoBadLog "Send email to ${email} failed, Please check ..."
            fi
        done
    }
    [ -f ${EMAIL_FILE} ] && rm -f ${EMAIL_FILE}
}

# 获取游戏服dblist
/usr/local/mysql/bin/mysql -h${LOGINIP} -u${USER} -p${PASSWORD} -P3306 --database=Login -Ne \
"SELECT DISTINCT dbip,dbport,dbname,real_sid FROM t_gameserver_list ORDER BY real_sid;" > ${DBLISTS} 

##
# 函数：备份mysqldb
#
bakMysqlDB(){
    DBIP=$1
    DBNAME=$2
    DBPORT=$3
    T_BAK_NAME=$4
    /usr/local/mysql/bin/mysqldump -u${USER} -p${PASSWORD} -P$DBPORT -h$DBIP $DBNAME --flush-logs \
    --single-transaction --master-data=2 | gzip > ${T_BAK_NAME}
    if [ $? -eq 0 ];then
        echoGoodLog "Backup $DBIP,$DBPORT,$DBNAME successfully."
    else
        echoBadLog "Backup $DBIP,$DBPORT,$DBNAME failed, Please check..."
    fi
}

# 备份游戏库
while read line;do
    DBIP=$(echo $line |awk '{print $1}')
    DBPORT=$(echo $line |awk '{print $2}')
    DBNAME=$(echo $line |awk '{print $3}')
    DBSID=$(echo $line |awk '{print $4}')
    T_BAK_NAME="${BACKPATH}${DBSID}.${T_YMDH}.sql.gz"
    bakMysqlDB ${DBIP} ${DBNAME} ${DBPORT} ${T_BAK_NAME}
done < ${DBLISTS}
# 备份登录库
bakMysqlDB ${LOGINIP} 'Login' '3306' "${BACKPATH}${T_YMDH}Login.sql.gz"
# 备份充值库
bakMysqlDB ${LOGINIP} 'Charge' '3306' "${BACKPATH}${T_YMDH}Charge.sql.gz"

# 打包所有数据库备份文件
cd ${BACKPATH} && {
    tar -zcvf ${BAK_NAME} --remove-files *.sql.gz
    if [ $? -eq 0 ];then
        echoGoodLog "Tar dbback successfully."
    else
        echoBadLog "Tar dbback failed, Please check..."
    fi
    find . -ctime +$KEEPDAY -type f -name "*.tar.gz" -delete
}

# 发送邮件，如果有报错的话
sendEmail
# 清理运行日志记录
cleanRunLog ${RUN_LOG}

