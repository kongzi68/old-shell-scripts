#!/bin/bash
# auto switch dns
# by colin
# on 2016-06-02
########################################
# 功能说明：该脚本运用于自动切换济南WEB下的所有子站DNS到青岛南WEB

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/cron_scripts_run.log'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${RUN_LOG}
}

echoGoodLog "Now, Script: `basename $0` run."
RUNLOG_MAX_NUM=10000
RUNLOG_MAX_DELNUM=5000

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`cat ${CLEANLOGFILE} |wc -l`
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && {
        sed -i "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE} && echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    echoGoodLog "Script: `basename $0` run done."
    exit
}

##
# CURL结果与PING结果
# STATUS枚举值：1表示济南服务器故障，0表示正常
# $1表示web端的IP，$2表示salt的minion分组
checkStatus(){
    curl http://${1}:81/index.php > /dev/null 2>&1
    [ $? -ne 0 ] && CURL_STATUS='1' || CURL_STATUS='0'
    PING_RESULT=$(salt -C "${2}*" test.ping |grep True|wc -l)
    [ ${PING_RESULT} -eq 0 ] && PING_STATUS='1' || PING_STATUS='0'   
}

##
# 执行远程DNS修改的状态值文件
# SWITCH_LOG的状态枚举值：1表示DNS切换指向了青岛南，0表示DNS正常
#
SWITCH_LOG='/var/log/web_jn_dns_switch_qdn.txt'
[ -e ${SWITCH_LOG} ] || echo -e "QDN:0\nJN:0" > ${SWITCH_LOG}

dnsSwitch(){
    SALT_GROUP="$1"
    IP1=$2
    IP2=$3
    LOG=$4
    SWITCH_STATUS=$(grep "$5" ${SWITCH_LOG} |awk -F: '{print $2}')
    if [ ${CURL_STATUS} -eq 1 -a ${PING_STATUS} -eq 1 ];then
        [ ${SWITCH_STATUS} -eq 0 ] && {
            salt -N ${SALT_GROUP} cmd.run "sed -i 's/${IP1}/${IP2}/g' /etc/bind/zones/wonaonao.com.db && /etc/init.d/bind9 restart" >> ${RUN_LOG}
            [ $? -eq 0 ] && {
                sed -i "/${5}/s/0/1/g" ${SWITCH_LOG}
                echoGoodLog "--->${4}'s DNS changesd; From ${5} to ${6}..."   
            }
        }
    elif [ ${CURL_STATUS} -eq 0 -a ${PING_STATUS} -eq 0 ];then
        [ ${SWITCH_STATUS} -eq 1 ] && {
            salt -N ${SALT_GROUP} cmd.run "sed -i 's/${IP2}/${IP1}/g' /etc/bind/zones/wonaonao.com.db && /etc/init.d/bind9 restart" >> ${RUN_LOG}
            [ $? -eq 0 ] && {
                sed -i "/${5}/s/1/0/g" ${SWITCH_LOG}
                echoGoodLog "--->${4}'s DNS changesd; From ${6} to ${5}..."
            }
        }
    fi
}

##
# 检测济南WEB，若故障就切换到青岛南
#
checkStatus 221.173.128.140 SDJN-TS-JN-WEB
dnsSwitch SDTS_BLJN 221.173.128.140 61.232.45.236 "JNX,TA,QFD,TZD,ZZ,ZB,WF,YT" JN QDN 

##
# 检测青岛南WEB，若故障就切换到济南
#
checkStatus 61.232.45.236 SDQD-TS-QDN-WEB
dnsSwitch  SDTS_BLQDN 61.232.45.236 221.173.128.140 "CL,GM,LC,QZ,QDB" QDN JN

cleanRunLog ${RUN_LOG}