#!/bin/bash
#每天切割日志文件，但不上传
#by colin
#revision on 2015-10-26
#
#功能说明：该脚本运用于every day cut log 
#更新说明：
#
#用于切割多个日志文件，每天切割备份一次，暂用
#
############################

#sleep 60   #延时60秒运行
SCRIPTSRUNLOG='/var/log/cron_scripts_run.log'
#函数：追加成功日志
echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${SCRIPTSRUNLOG}
}
#函数：追加失败日志
echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${SCRIPTSRUNLOG}
}

#调用日志追加函数
echoGoodLog "Now, Script: $0 will run."

############################
SERVERNAME=`hostname`          #=>部署的时候需要修改的变量
#SERVERNAME="dqdweb"            #=>部署的时候需要修改的变量
LOGSPATH="/data/store/logs/www/"     #日志所在文件夹
#文件夹路径示例：/data/store/logs/backup/
BACKLOGSPATH="/data/store/logs/backup/"       #把日志备份到这个文件夹
NGINXPIDPATH="/var/run/nginx.pid"
#定义数组：需要备份的日志类型
LOGTYPE=(
    imgm
    imga
    tongji
    appui
    ms
)

############################
NGINXPID=`cat ${NGINXPIDPATH}`
T=`echo $(date +%k)|sed 's/ //g'`
#last_hour_time=`date -d "1 hour ago" +%H`
#last_hour_time=`date -d "1 hour ago" +%Y-%m-%d-%H`
#这里临时修改变量取值，暂用
LASTDAYTIME=`date -d "yesterday" +%Y-%m-%d`
#last_week_time=`date -d "yesterday" +%w`
for i in ${LOGTYPE[@]}
do
    #创建备份日志存储文件夹
    [ -f ${LOGSPATH}${LOGNAME}.log ] && [ -d ${BACKLOGSPATH}${i} ] || mkdir -p ${BACKLOGSPATH}${i}
    #每小时切割与备份nginx生成的日志
    TARLOGDAYNAME="${LASTDAYTIME}.${SERVERNAME}.${i}log.tar.gz"
    LOGNAME="${i}_wonaonao_access"
    #先判断这个文件是否存在，不存在才执行后面的命令
    cd ${BACKLOGSPATH}${i} && [ -f ${TARLOGDAYNAME} ] || {
        if [ -f ${LOGSPATH}${LOGNAME}.log ];then
            mv ${LOGSPATH}${LOGNAME}.log ${LOGNAME}_${LASTDAYTIME}.log
            #切割日志文件
            [ -f ${LOGNAME}_${LASTDAYTIME}.log ] && kill -USR1 ${NGINXPID} || echoBadLog "LOG: ${LOGNAME}_${LASTDAYTIME}.log is not exist..."
            #打包日志文件    
            tar -zcf ${TARLOGDAYNAME} --remove-files ${LOGNAME}_${LASTDAYTIME}.log 
            if [ $? -eq 0 ] && [ -f ${TARLOGDAYNAME} ];then
                echoGoodLog "Tar: ${TARLOGDAYNAME} is successfully."
            else
                echoBadLog "Tar: ${TARLOGDAYNAME} was failed, Please check..."
            fi
            #清理超过90天的备份日志
            [ -d ${BACKLOGSPATH}${i} ] && cd ${BACKLOGSPATH}${i} && {
                for filename in `find . -type f -ctime +90 | awk -F/ '{print $2}'`
                do
                    rm  ${filename}
                    [ $? -eq 0 ] && echoGoodLog "Clear: ${BACKLOGSPATH}${i}${filename}."
                done
            }            
        else
            echoBadLog "The ${LOGSPATH}${LOGNAME}.log is not exist..."
            注释掉重启服务的功能
            /usr/sbin/service nginx restart
            if [ $? -eq 0 ];then
                echoGoodLog "Restart nginx is done."
            else
                echoBadLog "Restart nginx is failed, Please check..."
            fi
            kill -SIGUSR2 `cat /run/php5-fpm.pid`
            if [ $? -eq 0 ];then
                echoGoodLog "Restart php5-fpm is done."
            else
                echoBadLog "Restart php5-fpm is failed, Please check..."
            fi
        fi
    }
done

#清理脚本运行日志记录
TEMP_WC=`cat ${SCRIPTSRUNLOG} |wc -l`
if [ "${TEMP_WC}" -gt 10000 ];then
    sed -i "1,5000d" ${SCRIPTSRUNLOG}
    echoGoodLog "Clean up the ${SCRIPTSRUNLOG}..."
    echoGoodLog "Script: $0 run done."
else
    echoGoodLog "Script: $0 run done."
    exit
fi
