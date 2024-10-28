#!/bin/bash
#by colin
#revision on 2016-01-28
########################################
#功能说明：该脚本运用于检测php-fpm状态并自动重启
#
#使用说明：
#
#更新说明：
#apt-get install heirloom-mailx dos2unix
########################################
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/check_php_fpm_status.log'
[ -f ${RUN_LOG} ] || touch ${RUN_LOG}
TEMP_EMAIL_FILES="/tmp/tempTelnetPhpfpmEmail.txt"
[ -f ${TEMP_EMAIL_FILES} ] && cat /dev/null > ${TEMP_EMAIL_FILES}

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoGoodLog "Now, Script: `basename $0` run."

EMAIL=(
    colin@rockhippo.cn
)

HOSTNAME=`echo $(hostname)|tr [a-z] [A-z]`
echoEmailTxt(){
    echo "$(date +%F" "%T), ${HOSTNAME}: $*" >> ${TEMP_EMAIL_FILES}
}
    
restartPhpfpm(){
    GOODNEWS='Restart php5-fpm is successfully.'
    BADNEWS='Restart php5-fpm was failed, Please check...'
    PHPPIDNUM=`ps -ef|grep "php"|grep -v grep|wc -l`
    [ ${PHPPIDNUM} -ge 1 ] && ps -ef|grep "php"|grep -v grep|awk '{print $2}'|xargs kill -9
    /etc/init.d/php5-fpm start
    if [ $? -eq 0 ];then
        echoGoodLog ${GOODNEWS}
        echoEmailTxt ${GOODNEWS}
        return 0
    else
        service php5-fpm start
        if [ $? -eq 0 ];then
            echoGoodLog ${GOODNEWS}
            echoEmailTxt ${GOODNEWS}
            return 0
        else
            echoBadLog ${BADNEWS}
            echoEmailTxt ${BADNEWS}
            return 1
        fi
    fi
}

sendEmail(){
    [ `cat ${TEMP_EMAIL_FILES}|wc -l` -eq 0 ] || { 
        for i in ${EMAIL[@]}
        do
            dos2unix -k ${TEMP_EMAIL_FILES} 
            mail -s "${HOSTNAME}: RESTART PHP-FPM RESULT" ${i} < ${TEMP_EMAIL_FILES}
            echoGoodLog "Send email to ${i}, Please check ..."
        done
    }
    [ -e ${TEMP_EMAIL_FILES} ] && rm ${TEMP_EMAIL_FILES}
}

TEL_LOG="/tmp/tmp_telnet_php_fpm.log"
/usr/bin/telnet iamIPaddress 9000 <<EOF > ${TEL_LOG}
quit
EOF
SOK=`cat ${TEL_LOG} | grep "Escape character" |wc -l`
if [ $SOK -eq 1 ];then
    echoGoodLog "Php-fpm is ok."
else
    restartPhpfpm
    sendEmail
fi
[ -e ${TEL_LOG} ] && rm ${TEL_LOG}

