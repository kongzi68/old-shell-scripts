#! /bin/sh  
# by colin on 2022-05-19
## iamIPaddress 上部署的jenkins总是挂掉
#+ 用macos的系统启动服务又报错，只能用脚本来检测拉起服务了

# PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
PATH=/opt/homebrew/opt/openjdk@11/bin:/Users/iamUserName-fe/.nvm/versions/node/v15.14.0/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

RUN_LOG='/tmp/auto_start_jenkins.log'
[ ! -f ${RUN_LOG} ] && touch ${RUN_LOG}

echoGoodLog() {
    echo "\033[32m$(date +%F' '%T) $*\033[0m"
}

echoBadLog() {
    echo "\033[31m$(date +%F' '%T) $*\033[0m"
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

cleanRunLog(){
    CLEANLOGFILE=${1?"Usage: $FUNCNAME log_file_name"}
    TEMP_WC=`wc -l ${CLEANLOGFILE} |awk '{print $1}'`
    [ "${TEMP_WC}" -gt "${RUNLOG_MAX_NUM}" ] && {
        sed -i '' "1,${RUNLOG_MAX_DELNUM}d" ${CLEANLOGFILE} && echoGoodLog "Clean up the ${CLEANLOGFILE}..."
    }
    scriptsUnlock  # 运行结束清理锁文件
    # 清理垃圾文件
    cd /tmp && find . -name "000000000*" -type f -ctime -10 -delete
    echoGoodLog "Script: `basename $0` run done."
    exit
}

num=$(ps -ef | grep jenkins.war | grep -vE "grep|$(basename $0)" | wc -l)
if [ $num -eq 0 ];then
    echoBadLog "jenkins process not exist..."
    ## 在脚本中用nohup的方式启动jenkins会导致无法加载开发者证书问题，待解决
    # nohup /opt/homebrew/opt/openjdk@11/bin/java -jar /opt/homebrew/opt/jenkins-lts/libexec/jenkins.war --httpPort=8080 &
    ## 用brew启动，但前提是需要在gui界面先用iamUserName-fe用户登录
    brew services restart jenkins-lts
    pid=$(ps -ef | grep jenkins.war | grep -v grep | awk '{print $2}')
    echoGoodLog "jenkins server is restart, pid: ${pid}." 
else
    echoGoodLog "jenkins service is running."
fi

# 清理运行日志记录
cleanRunLog ${RUN_LOG}