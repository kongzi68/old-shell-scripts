#!/bin/bash
# description:Trian Server backup databases
# revision on 2016-02-19
# by colin
#
####################################
##
# 特别说明，只能用于备份并存储在本地的其它文件夹
# 功能说明：该脚本运用于mysql每天备份
#
# 使用说明：
# ./mysql_backup.sh /home/upload/229/mysql
# 
#
####################################
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/cron_scripts_run.log'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

EchoGoodLog ()
{
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

EchoBadLog ()
{
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

EchoGoodLog "Now, Script: `basename $0` run."
CD_DIR="${1?Usage: $(basename $0) /mysql/hlj/qqhr/}"
RUNLOG_MAX_NUM=100000
RUNLOG_MAX_DELNUM=5000
BACK_SAVE_MAX_DAY=60        # 存储10天内的备份 #
#############################
# [0-6],0表示星期天，1-6表示星期一至星期六
#+ BACKUP_FULL_DAY=6表示在每周的第6天进行全备
#
BACKUP_FULL_DAY=6
#############################

CleanRunLog ()
{
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`cat ${CLEANLOGFILE} |wc -l`
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && {
        sed -i "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE} && EchoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    EchoGoodLog "Script: `basename $0` run done."
    exit 0
}

#############################
##
# 下面这两个变量设置为固定值，
#+ 就可以进行相应的模拟调试
#
#NOWTIME='2016-09-01'
#WEEK_DAY='6'
NOWTIME=$(date +%Y-%m-%d)
WEEK_DAY=$(date +%w)
#############################
FILEBAKDIR='/data/store/dbback'
MYSQL_DATA_DIR='/data/mysql'
BIN_lOG_NAME='mysql-bin'
DBUSER='IamUsername'
DBPASSWD='password'
FILETYPE='mysql_bak'

##
# 全备mysql指定数据库
# $1：需要备份的数据库名;
#+ $2：刷新bin-log的标记Y，不传递参数$2时，默认值N。
# Usage: FullBackMysqlData rht_train Y
#
FullBackMysqlData ()
{
    local DATA_NAME=$1
    FLUSH_LOG=${2:-N}
    BACK_SQL_NAME="$NOWTIME.${DATA_NAME}.sql"
    BACK_TAR_NAME="${BACK_SQL_NAME%.sql}.tar.gz"
    [ -d "$FILEBAKDIR/${DATA_NAME}" ] || mkdir  $FILEBAKDIR/$DATA_NAME -p
    cd $FILEBAKDIR/$DATA_NAME && {
        if [ "${FLUSH_LOG}" = 'Y' ];then
            mysqldump -u$DBUSER -p$DBPASSWD  --default-character-set=utf8 --flush-logs -R ${DATA_NAME} > ${BACK_SQL_NAME}
        else
            mysqldump -u$DBUSER -p$DBPASSWD  --default-character-set=utf8 -R ${DATA_NAME} > ${BACK_SQL_NAME}
        fi
        if [ $? -eq 0 ];then
            EchoGoodLog "Backup: ${DATA_NAME} was successfully."
            tar -zcf  ${BACK_TAR_NAME} --remove-files ${BACK_SQL_NAME}
            if [ $? -eq 0 ];then
                [ -e "${BACK_TAR_NAME}" ] && EchoGoodLog "Tar: ${DATA_NAME} was successfully."
            else
                EchoBadLog "Tar: ${DATA_NAME} was failed, Please check..."
            fi
        else
            EchoBadLog "Backup: ${DATA_NAME} was failed, Please check..."
        fi  
    } 
}

##
# 增量备份：备份binlog日志
#
BackMysqlBinLog ()
{
    local BACK_DIR=$1
    BACK_BINLOG_NAME="$NOWTIME.B${WEEK_DAY}.tar.gz"
    [ -d ${BACK_DIR} ] || mkdir -p ${BACK_DIR}
    cd ${BACK_DIR} && mv -t ${BACK_DIR} $( find ${MYSQL_DATA_DIR} -name "mysql-bin.*" | grep -E "[0-9]{6}" ) && {
        mysql -u$DBUSER -p$DBPASSWD -e "use mysql;flush logs;"      # 需要用户有mysql库的权限 #
        tar -czf $FILEBAKDIR/${BACK_BINLOG_NAME} --remove-files * && EchoGoodLog "Backup: ${BACK_BINLOG_NAME} was successfully."
    } || EchoBadLog "Cut: ${BACK_BINLOG_NAME} was failed, Please check..."
    return 0
}

##
# 清理超过90天的备份
#
CleanOldFile()
{
    local CLEAN_DIR=$1
    [ -d "${CLEAN_DIR}" ] && cd ${CLEAN_DIR} && {
        for FILENAME in `find . -maxdepth 1 -name "*.tar.gz" -ctime +${BACK_SAVE_MAX_DAY} | awk -F/ '{print $2}'`
        do
            rm $FILENAME && EchoGoodLog "Clear: ${CLEAN_DIR}/$FILENAME."
        done    
    }
}

##
# 全备
#
[ "${WEEK_DAY}" -eq "${BACKUP_FULL_DAY}" ] && {
    xx=1
    MYSQL_BACKUP_LIST='/var/log/mysqlbackuplist'
    mysql -u$DBUSER -p$DBPASSWD -e "show databases;" | grep "rht_" > ${MYSQL_BACKUP_LIST}
    LAST_WHILE_NUM=$(wc -l < ${MYSQL_BACKUP_LIST})
    while read noteline
    do
        [ "${xx}" -ge "${LAST_WHILE_NUM}" ] && FullBackMysqlData $noteline Y || FullBackMysqlData $noteline
        xx=$( expr $xx + 1 )
        LCD_DIR="${FILEBAKDIR}/${noteline}"     # 申明变量LCD_DIR给函数RunSendLog使用 #
        cp -a ${LCD_DIR}/${BACK_TAR_NAME} ${CD_DIR}
        CleanOldFile ${LCD_DIR}
    done < ${MYSQL_BACKUP_LIST}
}

##
# 增量备份
#
LCD_DIR="${FILEBAKDIR}"         # 申明变量LCD_DIR给函数RunSendLog使用 #
BackMysqlBinLog "${LCD_DIR}/${WEEK_DAY}" && {
    [ -e "${LCD_DIR}/${BACK_BINLOG_NAME}" ] && cp -a ${LCD_DIR}/${BACK_BINLOG_NAME} ${CD_DIR} && CleanOldFile ${LCD_DIR}
    [ -d "${LCD_DIR}/${WEEK_DAY}" ] && rm -rf "${LCD_DIR}/${WEEK_DAY}"
}

CleanRunLog ${RUN_LOG}
