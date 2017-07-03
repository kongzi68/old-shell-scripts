#!/bin/bash
# get system and services status
# by colin
# revision on 2015-10-15
########################################
# 功能说明：该脚本用于收集系统和各种服务的状态信息
#
# 部署脚本时，加参数请注意参数顺序，否则会影响传上去的数据解析结果
#+ 命令：sh system_status_v3.sh -l -m -g 
#
# 更新说明：
#
########################################

#sleep 60        #延时60秒运行

##
# gonet的errorcode,检测距离当前时间5分钟以内的
#
CHECK_T=5
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SCRIPT_NAME='status'
PROGNAME=`basename $0`
scripts_run_log='/var/log/system_status_run_status.log'

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" >> ${scripts_run_log}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" >> ${scripts_run_log}
}

echoGoodLog "Now, Script $0 will run..."
RUNLOG_MAX_NUM=100000
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
# 定义需要采集的系统信息
#
HOST_NAME=`hostname`
IP_ADDR=`/sbin/ifconfig |grep -v "eth[0-9]:[0-9]"|grep -EA 1 "eth0|eth1"|head -2|grep "Bcast:"|sed "s/:/ /g"|awk '{print $3}'`
MEMORY_INFO1=`free -m|grep "Mem"|awk '{print $2}'`
MEMORY_INFO2=`free -m|grep "cache:"|awk '{print $NF}'`
LOAD_AVERAGE=`uptime |awk -F, '{print $5}'|sed "s/ //g"`
CPU_CORE_NUM=`cat /proc/cpuinfo|grep "model name"|wc -l`
CPU_FREE=`/usr/bin/top -bcn 1|grep "Cpu"|awk -F, '{print $4}'|sed "s/%id//g"|sed "s/ //g"|head -n 1`

##
# 定义数组：需要检测的服务
# 定义格式：服务名:端口号 
# 需要检测的服务常用如下：
#+ nginx:80
#+ nginx:81
#+ php-fpm:9000
#+ bind:53
#+ memcached:11211
#+ keepalived:
#
need_check_service=(
    nginx:80
    php-fpm:9000
    memcached:11211    
)

########################################
temp_status="/tmp/temp_status$$.txt"
temp_info="/tmp/temp_info.txt"

LOGTIME=`date -d "$(date +%F" "%T)" +%s`
LOG_INTERVAL=`expr ${LOGTIME} % 3600`
[ ${LOG_INTERVAL} -lt 300 ] && {
    /usr/sbin/ntpdate cn.pool.ntp.org >> ${scripts_run_log} && echoGoodLog "Update time is successfully."
}

##
# 函数功能：把多行的数据处理成一行
#
do_txt(){
    temp_do=""
    while read line
    do
        temp_do="${temp_do} ${line}"
    done < ${temp_info}
    do_done=`echo ${temp_do}|sed 's/ /;/g'`
}

echo "Servername::${HOST_NAME}-${IP_ADDR}" >> ${temp_status}
echo "Mem::${MEMORY_INFO1},${MEMORY_INFO2}" >> ${temp_status}
echo "Cpu::${CPU_FREE}" >>${temp_status}
echo "Load_average::${LOAD_AVERAGE},${CPU_CORE_NUM}" >> ${temp_status}

##
# 流量处理
#
temp_done_file1="/tmp/temp_done_file1$$.txt"
temp_done_file2="/tmp/temp_done_file2$$.txt"
temp_done_file3="/tmp/temp_done_file3$$.txt"
TEMP_DONE_NET_FILE="/tmp/.temp_netcard_done_file.txt"
[ -f ${TEMP_DONE_NET_FILE} ] || touch ${TEMP_DONE_NET_FILE}
/sbin/ifconfig |grep -v "eth[0-9]:[0-9]"|grep -A 1 "eth[0-9]"|awk '{print $1" "$2}'|sed 's/:/ /g'|grep -v "\-\-"  > ${temp_info}
while_num=`expr $(cat ${temp_info}|wc -l) / 2`
for ((i=1;i<=${while_num};i++))
do
    n=$(( $i * 2 ))
    m=`expr $n - 1`
    sed -n "${m},${n}p" ${temp_info} > ${temp_done_file1}
    a=`sed -n "1p" ${temp_done_file1}|awk '{print $1}'`
    b=`sed -n "2p" ${temp_done_file1}|awk '{print $NF}'`
    echo "$a $b" >> ${temp_done_file2}
done
##
#cat ${temp_done_file2}
# 这里获取的网卡流量为总流量，每秒的流量需要计算才能得出
#
NETCARD_FLOW=`cat /proc/net/dev|grep eth|awk '{if($2>0) print $1$2","$10}'|sed 's/:/ /g'`
##
# 当前的网卡总流量数据，临时保存备用
#
echo "${NETCARD_FLOW}" > ${temp_done_file1}
##
# ($6-$3)*8/1024/1024/300，表示当前的网卡总流量减去五分钟之前的总流量*8之后
#+ 两次除以1024得到单位MB级别，在除以300s后，就等于类似的5MB/s，只是没有带单位而已，即5
#
paste ${TEMP_DONE_NET_FILE} ${temp_done_file1}|sed "s/,/ /g" > ${temp_done_file3}
cat /dev/null > ${temp_done_file1}
while read line
do
    ##
    # 若修改了计划执行的时间，这里需要修改300s为相应的值
    #
    echo "$line" |awk '{OFMT="%4.6f";print $1,($5-$2)*8/1024/1024/300,($6-$3)*8/1024/1024/300}' >> ${temp_done_file1}
done < ${temp_done_file3}
paste ${temp_done_file1} ${temp_done_file2} |awk '{print $1"::"$NF","$2","$3}' > ${temp_info}
do_txt
echo "${do_done}" >> ${temp_status}
[ -f ${temp_done_file1} ] && rm ${temp_done_file1}
[ -f ${temp_done_file2} ] && rm ${temp_done_file2}
[ -f ${temp_done_file3} ] && rm ${temp_done_file3}
##
# 保留本次获取的网卡流量数据，以备下次运行时使用
#
echo "${NETCARD_FLOW}" > ${TEMP_DONE_NET_FILE}

##
# 磁盘信息处理
#
df -hP|grep -E "/$|home$|data$"|awk '{print $NF"::"$2","$4","$5}' > ${temp_info}
do_txt
echo "${do_done}" >> ${temp_status}
#echo "========================"

####################################
temp_services_status='/tmp/temp_services_status.txt'
##
# 函数功能：判断进程与端口
#+ 进程数量等于0或者是端口不存在，都表示服务未启动
#
check_pid_port(){
    NUMSERVERS=`ps -ef |grep "$1" |grep -Ev "grep|${SCRIPT_NAME}"|wc -l`
    PORT_NUM=`netstat -natul|awk '{print $4}'|awk -F: '{print $2}'|grep -w "$2"|wc -l`
    if [ ${NUMSERVERS} -eq 0 -o ${PORT_NUM} -eq 0 ];then
        services_stauts="$1::0"
        return 1
    else
        services_stauts="$1::1"
        return 0
    fi
}

for i in ${need_check_service[@]}
do
    service_name=`echo $i|awk -F: '{print $1}'`
    service_port=`echo $i|awk -F: '{print $2}'`
    check_pid_port ${service_name} ${service_port}
    echo "${services_stauts}" >> ${temp_services_status}
done

## 
# 函数功能：检测LNMP或者是nginx服务的状态
#
check_lnmp(){
    lnmp_conf_dir='/etc/nginx/sites-enabled/'
    temp_hostname_files="/tmp/temp_hostname_files$$.txt"
    echo "${HOST_NAME}" > ${temp_hostname_files}
    temp_hostname_num=`grep -Eo "HLS|WEB" ${temp_hostname_files} |sort|uniq -c|wc -l`
    if [ ${temp_hostname_num} -eq 2 ];then
        temp_hostname="WEB"
    else
        temp_hostname=`grep -Eo "HLS|WEB" ${temp_hostname_files}`
    fi
    if [ "${temp_hostname}" = "WEB" ];then
        lnmp_conf='m_wonaonao_com.conf'
        temp_test_files="test$$.php"
    elif [ "${temp_hostname}" = "HLS" ];then
        lnmp_conf='hls_wonaonao_com.conf'
        temp_test_files="test$$.html"
    fi
    [ -f ${temp_hostname_files} ] && rm ${temp_hostname_files}
    [ -f ${lnmp_conf_dir}${lnmp_conf} ] && www_dir=`grep -w "root" ${lnmp_conf_dir}${lnmp_conf}|awk '{print $2}'|sed 's#;#/#g'`
    [ -d ${www_dir} ] && cd ${www_dir} && touch ${temp_test_files} && {
        lnmp_test_files="${www_dir}${temp_test_files}"
        if [ "${temp_hostname}" = "WEB" ];then
            cat > ${lnmp_test_files} <<EOF
<?php
\$mem= new Memcache;
\$mem->connect('127.0.0.1',11211);
\$mem->set('test','LNMP and Memcached is ok!',0,12);
\$val= \$mem->get('test');
echo \$val;
?>
EOF
        elif [ "${temp_hostname}" = "HLS" ];then
            cat > ${lnmp_test_files} <<EOF
<html>
<body>
<h1>This is test.</h1>
<p>Nginx is ok!</p>
</body>
</html>
EOF
        fi
    }
    temp_curl_status="/tmp/temp_curl_status$$.txt"
    cd /tmp && touch ${temp_curl_status}
    curl -I http://127.0.0.1/${temp_test_files} > ${temp_curl_status}
    [ -f ${lnmp_test_files} ] && rm ${lnmp_test_files}
    #echo "========================"
    lnmp_status=`cat ${temp_curl_status} |head -1|awk '{print $2}'`
    [ ${lnmp_status} -eq 200 ] &&  echo "web_services::1" >> ${temp_services_status} || echo "web_services::0" >> ${temp_services_status}
    [ -f ${temp_curl_status} ] && rm ${temp_curl_status}
    [ -f ${temp_hostname_files} ] && rm ${temp_hostname_files}
}

mysql_user='wifidb'
mysql_passwd='ZdEa_phN7bNQQq8'
#函数功能：检测mysql与mysql主从状态
check_mysql(){
    temp_hostname_files="/tmp/temp_hostname_files$$.txt"
    echo "${HOST_NAME}" > ${temp_hostname_files}
    temp_hostname=`grep -o "WEB2" ${temp_hostname_files}`
    #调用函数check_pid_port，检测mysql进程数量和端口号
    check_pid_port mysql 3306
    [ `echo $?` -eq 0 ] && MYSQL_STATUS='1' || MYSQL_STATUS='0' 
    #################################
    #processlist:客户端连接进程数
    #Threads_created:当前已连接的数量
    #Threads_connected:当前打开的连接数
    #Threads_running:当前未挂起的连接数
    #################################
    MYSQL_PROC_NUM=`mysql -u${mysql_user} -p${mysql_passwd} -e "show processlist;"|grep wifidb|wc -l`
    MYSQL_THR_CRE=`mysql -u${mysql_user} -p${mysql_passwd} -e "show status like 'Threads_created'\G"|grep " Value"|awk -F: '{print $2}'|sed 's/ //g'`
    MYSQL_THR_CON=`mysql -u${mysql_user} -p${mysql_passwd} -e "show status like 'Threads_connected'\G"|grep " Value"|awk -F: '{print $2}'|sed 's/ //g'`
    MYSQL_THR_RUN=`mysql -u${mysql_user} -p${mysql_passwd} -e "show status like 'Threads_running'\G"|grep " Value"|awk -F: '{print $2}'|sed 's/ //g'`
    echo "Mysql::${MYSQL_STATUS},${MYSQL_PROC_NUM},${MYSQL_THR_CRE},${MYSQL_THR_CON},${MYSQL_THR_RUN}" >> ${temp_services_status}
    if [ "${temp_hostname}" = "WEB2" ];then
        #check start status;
        SLAVE_IO_STATUS=`mysql -u${mysql_user} -p${mysql_passwd} -e "show slave status \G" |grep Slave_IO_Running | awk '{print $2}'|tr [A-Z] [a-z]`
        SLAVE_SQL_STATUS=`mysql -u${mysql_user} -p${mysql_passwd} -e "show slave status \G" |grep Slave_SQL_Running | awk '{print $2}'|tr [A-Z] [a-z]`
        SLAVE_INFO="${SLAVE_IO_STATUS}${SLAVE_SQL_STATUS}"
        case ${SLAVE_INFO} in
            yesyes)
                echo "mysql_slave::IO:1,SQL:1" >> ${temp_services_status}
                ;;
            yesno)
                echo "mysql_slave::IO:1,SQL:0" >> ${temp_services_status}
                ;;
            noyes)
                echo "mysql_slave::IO:0,SQL:1" >> ${temp_services_status}
                ;;
            nono)
                echo "mysql_slave::IO:0,SQL:0" >> ${temp_services_status}
                ;;
        esac
    fi
    [ -f ${temp_hostname_files} ] && rm ${temp_hostname_files}
}

#函数功能：检测gonet日志文件中的errorcode值
#
check_gonet(){
    gonetdir='/data/store/logs/yjww/'
    TEMP_GONET="/tmp/check_gonet$$.txt"
    TEMP_GONET_FILE="/tmp/temp_gonet_file$$.txt"
    #当没有这个目录的时候，就跳出，不执行函数的其它功能
    [ -d ${gonetdir} ] || break
    t_month=`date +%Y%m`
    t_last_hour=`date -d '1 hour ago' +%H`
    t_hour=`date +%H`
    t_yesterday=`date -d "yesterday" +%d`
    t_today=`date +%d`
    T=`echo $(date +%k) |sed 's/ //g'`
    #凌晨的时候，文件目录是昨天的
    if [ $T -eq 0 ];then
        temp_gonetdir=${gonetdir}${t_month}/${t_yesterday}/
    else
        temp_gonetdir=${gonetdir}${t_month}/${t_today}/
    fi
    #每个整点的时候，yjww日志文件会重新生成
    MINU_VALUES=`date -d "$(date)" +%M|sed "s/^0//g"`
    #脚本在整点的时候运行，运行间隔时间为5的倍数,即CHECK_T=5
    #当比如时间是在这个区间时：15:00:00~15:05:00时，就会去检测上一个小时的yjww日志。
    #实际上这里，只是为了当整点的时候，去检测上一个小时的日志文件，在逻辑上这里不严谨，有问题
    #最好的方法是每运行一次，合并上个小时的日志文件与当前小时的日志文件，这样就避免了整点这个问题了，并且这样更准确。
    if [ ${MINU_VALUES} -lt ${CHECK_T} ];then
        gonet_log_name="yjww_${t_last_hour}.log"
    else
        gonet_log_name="yjww_${t_hour}.log"
    fi
    #当没有这个目录的时候，就跳出，不执行函数的其它功能
    [ -d ${temp_gonetdir} ] || break
    cd ${temp_gonetdir} && {
        [ -f ${gonet_log_name} ] && {
            cat -n ${gonet_log_name}|grep "$(date +%F)" |awk -F'--->' '{print $1}' > ${TEMP_GONET}
            while read line
            do
                TIMEA=`date -d "$(echo $line |awk '{print $2,$3}')" +%s`
                NOWTIME=`date -d "$(date)" +%s`
                INTERVAL=`expr "$(expr ${NOWTIME} - ${TIMEA})" / 60`
                #时间是倒叙，检测最新时间间隔内的数据,所以用-le
                #CHECK_T是检测最近5分钟的数据，需要在部署的时候设置，目前是5分钟
                if [ ${INTERVAL} -le ${CHECK_T} ];then
                    m=`echo $line |awk '{print $1}'`
                    break
                fi
            done < ${TEMP_GONET}
            n=`cat ${gonet_log_name}|wc -l`
            sed -n "${m},${n}p" ${gonet_log_name} > ${TEMP_GONET_FILE}
            #0、2是正常认证的枚举值；1、3、4是认证失败等的枚举值
            errorcode0=`grep -B 11 "\[errorcode1\] => 0" ${TEMP_GONET_FILE}|grep '\--->'|awk -F '>' '{print $2}'|uniq|wc -l`
            errorcode2=`grep -B 11 "\[errorcode1\] => 2" ${TEMP_GONET_FILE}|grep '\--->'|awk -F '>' '{print $2}'|uniq|wc -l`
            ############################
            errorcode1=`grep -B 11 "\[errorcode1\] => 1" ${TEMP_GONET_FILE}|grep '\--->'|awk -F '>' '{print $2}'|uniq|wc -l`
            errorcode3=`grep -B 11 "\[errorcode1\] => 3" ${TEMP_GONET_FILE}|grep '\--->'|awk -F '>' '{print $2}'|uniq|wc -l`
            errorcode4=`grep -B 11 "\[errorcode1\] => 4" ${TEMP_GONET_FILE}|grep '\--->'|awk -F '>' '{print $2}'|uniq|wc -l`
            echo "gonet::`expr ${errorcode0} + ${errorcode2}`,`expr ${errorcode1} + ${errorcode3} + ${errorcode4}`" >> ${temp_services_status}
        } || echo "gonet::0,0"  >> ${temp_services_status}
        [ -f ${TEMP_GONET} ] && rm ${TEMP_GONET}
        [ -f ${TEMP_GONET_FILE} ] && rm ${TEMP_GONET_FILE}
    }
}

#脚本帮助提示函数
scripts_help(){
    echo "Usage parameters:"
    echo "$PROGNAME [-l/--lnmp] [-m/--mysql]"
    echo "Options:"
        echo " -l/--lnmp)"
        echo "    call function check_lnmp"
        echo " -m/--mysql)"
        echo "    call function check_mysql"
        echo " -g/--gonet)"
        echo "    call function check_gonet"
    echo "Example:"
    echo "./system_status.sh -l -m -g"
}

#判断是否带参数
if [ -z "$*" ];then
   scripts_help
else
    #脚本传参数，调用相应的函数功能
    while test -n "$1";do
        case "$1" in
            --help|-h)
                scripts_help
                ;;
            --lnmp|-l)
                check_lnmp
                ;;
            --mysql|-m)
                check_mysql
                ;;
            --gonet|-g)
                check_gonet
                ;;
            *)
                echo "Unknown argument: $1"
                scripts_help
                ;;
        esac
        shift
    done
fi

#汇总检测的服务状态信息为一条数据，并追加到${temp_status}
services_info=`cat ${temp_services_status}|xargs|sed 's/ /;/g'`
echo "${services_info}" >> ${temp_status}
[ -f ${temp_services_status} ] && rm ${temp_services_status}

#汇总所有检测信息为一条数据
system_info=`cat ${temp_status}|xargs`
[ -f ${temp_status} ] && rm ${temp_status}
[ -f ${temp_info} ] && rm ${temp_info}

echo "datatype::server datastr::$(date +%s) ${system_info}"  >> ${scripts_run_log}
curl -F "datatype=server" -F "datastr=$(date +%s) ${system_info}" http://monitor.hoobanr.com/monitor.php


#清理脚本运行日志记录
cleanRunLog ${scripts_run_log}


