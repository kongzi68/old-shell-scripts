#!/bin/bash
# bak_mysql.sh
# by qyq on 2017-04-01
# revision on 2017-04-01
##################################
##脚本功能：
# 备份数据库，用于审计
#
##脚本说明：
# 00 04 * * * /data/script/bak_mysql_shenji.sh > /dev/null 2>&1
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
EMAIL_FILE='/tmp/bak_mysql_shenji_email.txt'
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

USER='IamUsername'
PASSWORD='thisispassword'
T_YMD=$(date +%y%m%d)
KEEPDAY=5
LOGINIP='iamIPaddress'
LOGINPORT=3306

BACKPATH='/data/db_backup/bak_mysql_shenji/'  # 路径最后一级必须加‘/’
# BACKPATH="/data/db_backup/bak_mysql_shenji_test/"  # 路径最后一级必须加‘/’
[ -d ${BACKPATH}${T_YMD} ] || mkdir -p ${BACKPATH}${T_YMD}
cd ${BACKPATH}${T_YMD}

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

##
# 函数：远程拷贝备份
#
scpBakDB(){
	REMOTEIP=$1
	REMOTEPATH=$2
	BAKPATH=$3
	scp -i ~/.ssh/3jianhao  -o StrictHostKeyChecking=no -r IamUsername@${REMOTEIP}:${REMOTEPATH}${T_YMD}/ ${BAKPATH}
	if [ $? -eq 0 ];then
        echoGoodLog "Backup ${REMOTEIP}:${REMOTEPATH} successfully."
    else
        echoBadLog "Backup ${REMOTEIP}:${REMOTEPATH} failed, Please check..."
    fi
}

#备份玩家宝石数据
/usr/local/mysql/bin/mysql -h${LOGINIP} -u${USER} -p${PASSWORD} -P3306 --database=Login -Ne \
"SELECT DISTINCT dbip,dbport,dbname,real_sid FROM t_gameserver_list ORDER BY real_sid;" | sort -u > ${BACKPATH}"list" 
cat ${BACKPATH}"list" |while read line
do
    ip=`echo $line|awk '{print $1}'`
    port=`echo $line|awk '{print $2}'`
    dbname=`echo $line|awk '{print $3}'`
    id=`echo $line|awk '{print $4}'`
    /usr/local/mysql/bin/mysql -u${USER} -p${PASSWORD} -P${port} -h${ip} --database=${dbname} -e \
	"set names utf8;use ProjectM;select c_cid,c_uid,c_charname,c_level,c_unbindgold from t_char_basic" >${id}.${T_YMD}.txt
	if [ $? -eq 0 ];then
        echoGoodLog "Backup ${ip}:${port}_${id}.${T_YMD}.txt successfully."
    else
        echoBadLog "Backup ${ip}:${port}_${id}.${T_YMD}.txt failed, Please check..."
    fi
done

#备份登陆数据库
bakMysqlDB ${LOGINIP} 'Login t_account t_gameserver_list' '3306' "${T_YMD}Login.sql.gz"
#备份充值库
bakMysqlDB ${LOGINIP} 'Charge IOSFinish TmallFinish' '3306' "${T_YMD}Charge.sql.gz"
#备份OSS_Record
scpBakDB 'iamIPaddress' '/data/db_backup/bak_mysql_oss_record/' ${BACKPATH}
scpBakDB 'iamIPaddress' '/data/db_backup/bak_mysql_oss_record/' ${BACKPATH}
#备份OSS
scpBakDB 'iamIPaddress' '/data/db_backup/bak_mysql_oss/' ${BACKPATH}

# 打包并清理数据
zip -r "projectm"${T_YMD}.zip *.txt
if [ $? -eq 0 ];then
    echoGoodLog "Zip projectm${T_YMD}.zip successfully."
else
    echoBadLog "Zip projectm${T_YMD}.zip failed, Please check..."
fi
rm -rf *.txt

#清理过期备份
cd ~
find ${BACKPATH} -ctime +${KEEPDAY} -exec rm -rf {} \;

# 发送邮件，如果有报错的话
sendEmail
# 清理运行日志记录
cleanRunLog ${RUN_LOG}
