#!/bin/bash
# mysql_install.sh
# by colin on 2016-08-26,29
# revision on 2017-03-09
##################################
##脚本功能：
# mysql单实例、多实例安装与配置
#+ 配置文件不分主从，通过在安装时选择相应的参数，来实现安装master或slave
#
##脚本使用
# ./mysql_install.sh -h
# ./mysql_install.sh -i 2 -t master 
#
##脚本说明：
# 1、解压二进制包，并移动到相应的目录下
# 2、创建相应的数据存储文件夹
# 3、配置文件生成
# 4、初始化配置
# 5、启动mysql，及启动后检查进程等
#
##更新记录：
#
##################################
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/scripts_run_status.log'

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" | tee -a ${RUN_LOG}
    sleep 1
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" | tee -a ${RUN_LOG}
    sleep 1
}

echoLine(){
    sleep 3
    echo -e "\033[34m================LINE BETWEEN================\033[0m"
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

echoToHelp(){
    echo -e "\033[32m $*\033[0m"
}

##
# 脚本帮助提示函数
#
scriptsHelp(){
    echoBadLog "======================================="
    echoToHelp "Usage parameters:"
    echoToHelp "./`basename $0` -i install_times -t mysql_type  "
    echoToHelp "Options:"
        echoToHelp "  -i)"
        echoToHelp "    必须的参数：install_times：实例被安装的个数；"
        echoToHelp "    安装一个实例，则：' -i 1' ；安装两个实例，则：' -i 2' ，依此类推。"
        echoToHelp "  -t)"
        echoToHelp "    必须的参数：mysql_type：安装的mysql是主还是从"
        echoToHelp "    若安装的mysql是主，则：'-t master'；若安装的mysql是从，则：'-t slave'"
    echoToHelp "Example:"
    echoToHelp "./`basename $0` -i 8 -t slave    # 表示安装8个从实例"
    echoToHelp "./`basename $0` -i 4 -t master   # 表示安装4个主实例"
    echoBadLog "======================================="
}

checkParameter(){
    PARAMETER=${1:-null}
    PARAMETER_STATUS=`echo "${PARAMETER}" |grep "^-"|wc -l`
    if [ "${PARAMETER_STATUS}" -eq 1 -o "${PARAMETER}" = "null" ];then
        scriptsHelp
        echoBadLog "Argument error, Please check..."
        exit
    fi
}

##
# 判断是否带参数
#
if [ -z "$*" ];then
   scriptsHelp
   exit
else
    ##
    # 脚本传参数，调用相应的函数功能
    #
    while test -n "$1";do
        case "$1" in
            -i)
                shift
                checkParameter $1
                INSTALL_TIMES=$1
                ;;
            -t)
                shift
                checkParameter $1
                case "$1" in
                    master)
                        BIN_LOG='yes'
                        ;;
                    slave)
                        BIN_LOG='no'
                        ;;
                    *)
                        echoBadLog "Unknown argument: -t $1"
                        scriptsHelp
                        exit
                        ;;
                esac
                ;;
            *)
                echoBadLog "Unknown argument: $1"
                scriptsHelp
                exit
                ;;
        esac
        shift
    done
fi

##
# 变量声明
#
MYSQL_CONFIG='/etc/my.cnf'
IPADDR=$(ifconfig eth0 | grep Bcast|awk '{print $2}'|cut -d ":" -f 2)
DATA_DIR='/data/mysql'      # 目录最后一级不需要 '/'

##
# mysql依赖包与常用工具包安装
#
yum install -y patch make cmake gcc gcc-c++ gcc-g77 flex bison file libtool libtool-libs autoconf \
    kernel-devel libjpeg libjpeg-devel libpng libpng-devel libpng10 libpng10-devel gd gd-devel freetype \
    freetype-devel libxml2 libxml2-devel zlib zlib-devel glib2 glib2-devel bzip2 bzip2-devel libevent \
    libevent-devel ncurses ncurses-devel curl curl-devel e2fsprogs e2fsprogs-devel krb5 krb5-devel libidn \
    libidn-devel openssl openssl-devel vim-minimal nano fonts-chinese gettext gettext-devel ncurses-devel \
    gmp-devel pspell-devel unzip libcap diffutils vim lszrz wget libaio dmidecode sysstat telnet

##
# 二进制mysql包安装
#
echoLine
echoGoodLog "Install mysql, Please wait."
tar -zxf mysql_master.tar.gz && cd master && {
    [ -d /usr/local/mysql ] && {
        echoBadLog "The /usr/local/mysql is exsits, Please check..."
        mv -f /usr/local/mysql /usr/local/mysql_$(date +%s)
    }
    mv mysql /usr/local/
    # 备份原有配置文件
    [ -f ${MYSQL_CONFIG} ] && mv ${MYSQL_CONFIG} ${MYSQL_CONFIG}.bak
    cd .. && rm -rf master
    [ -d /usr/local/mysql ] && echoGoodLog "Install mysql is done."
}

##
# 配置文件的开始段
#
echoLine
echoGoodLog "Create /etc/my.cnf  "
if [ "${INSTALL_TIMES}" -le 1 ];then
    cat > ${MYSQL_CONFIG} <<EOF
[client]
port       = 3306
socket     = ${DATA_DIR}/mysql/data/mysql.sock

EOF
else
    # 多实例
    cat > ${MYSQL_CONFIG} <<EOF
[client]
port       = 3306
socket     = ${DATA_DIR}/mysql1/data/mysql.sock

[mysqld_multi]
mysqld     = /usr/local/mysql/bin/mysqld_safe
mysqladmin = /usr/local/mysql/bin/mysqladmin

EOF
fi

##
# 创建配置文件的中间段
#
for ((i=1;i<=${INSTALL_TIMES};i++))
do
    if [ ${INSTALL_TIMES} -le 1 ];then
        TMP_I=''
        TMP_ID=0
        MYSQL_PORT=3306
    else
        TMP_I=$i
        TMP_ID=$i
        MYSQL_PORT=$(expr 3306 + $i - 1)
    fi
    # 创建数据存储目录
    mkdir -p ${DATA_DIR}/mysql${TMP_I}/{data,innodb/data,innodb/log,log,logbin}
    cat >> ${MYSQL_CONFIG} <<EOF
[mysqld${TMP_I}]
EOF
    # 根据传参结果，来判断是主还是从
    if [ "${BIN_LOG}" = 'no' ];then
        TMP_M_LAG=20
    elif [ "${BIN_LOG}" = 'yes' ];then
        TMP_M_LAG=10
        cat >> ${MYSQL_CONFIG} <<EOF
log-bin             = ${DATA_DIR}/mysql${TMP_I}/logbin/mysql-bin
binlog_format       = mixed
expire_logs_days    = 7
EOF
    fi
    cat >> ${MYSQL_CONFIG} <<EOF
server-id           = ${TMP_M_LAG}${TMP_ID}
replicate-ignore-db = mysql 
bind-address        = ${IPADDR}
port                = ${MYSQL_PORT}
datadir             = ${DATA_DIR}/mysql${TMP_I}/data
basedir             = /usr/local/mysql
socket              = ${DATA_DIR}/mysql${TMP_I}/data/mysql.sock
default-storage-engine  = INNODB
character-set-server   = utf8
back_log            = 500
max_connections     = 1024
max_connect_errors  = 102400
max_allowed_packet  = 16M
query_cache_type    = 1
query_cache_size    = 32M
query_cache_limit   = 1M
max_heap_table_size = 64M
sort_buffer_size    = 8M
join_buffer_size    = 8M
thread_cache_size   = 100
thread_concurrency  = 8
thread_stack        = 192K
ft_min_word_len     = 4
tmp_table_size      = 64M
binlog_cache_size   = 1M
key_buffer_size     = 32M
myisam_repair_threads = 1
myisam_recover
wait_timeout        = 120
interactive_timeout = 120
skip-name-resolve
sql-mode            = NO_ENGINE_SUBSTITUTION
innodb_flush_method         = O_DIRECT
transaction_isolation       = REPEATABLE-READ
innodb_file_per_table       = 1
innodb_buffer_pool_size     = 3G
innodb_lock_wait_timeout    = 120
innodb_thread_concurrency   = 16
innodb_file_io_threads      = 4
innodb_mirrored_log_groups  = 1
innodb_max_dirty_pages_pct  = 90
innodb_log_file_size        = 128M
innodb_log_buffer_size      = 8M
innodb_log_files_in_group   = 4
innodb_flush_log_at_trx_commit  = 0
innodb_additional_mem_pool_size = 16M
innodb_data_file_path       = ibdata1:2G;ibdata2:2G:autoextend
innodb_data_home_dir        = ${DATA_DIR}/mysql${TMP_I}/innodb/data
innodb_log_group_home_dir   = ${DATA_DIR}/mysql${TMP_I}/innodb/log
pid-file                    = ${DATA_DIR}/mysql${TMP_I}/mysqld.pid

EOF
done

##
# 追加配置文件的最后段
#
cat >> ${MYSQL_CONFIG} <<EOF
[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
pager = more
no-auto-rehash
#prompt = '[\u@\h] (\d) \R:\m>'

[isamchk]
key_buffer  = 64M
sort_buffer = 64M
read_buffer = 8M
write_buffer= 8M

[myisamchk]
key_buffer  = 64M
sort_buffer = 64M
read_buffer = 8M
write_buffer= 8M

[mysqlhotcopy]
interactive-timeout

[mysqld_safe]
open-files-limit= 65535
user            = mysql
log-error       = ${DATA_DIR}/mysql/log/mysqld.log    
EOF

# 创建日志存储目录，当单实例的时候，前面已经创建了，所以需要进行检测
[ -d ${DATA_DIR}/mysql/log ] || mkdir -p ${DATA_DIR}/mysql/log 

# 创建用户与组，及权限设置
groupadd mysql
useradd -g mysql mysql
chown -R mysql.mysql /usr/local/mysql ${DATA_DIR}/mysql*
chmod 644 ${MYSQL_CONFIG} && chown mysql.mysql ${MYSQL_CONFIG}

##
# 初始化数据
#
for ((i=1;i<=${INSTALL_TIMES};i++))
do
    if [ ${INSTALL_TIMES} -le 1 ];then
        TMP_I=''
    else
        TMP_I=$i
    fi
    /usr/local/mysql/scripts/mysql_install_db --user=mysql --basedir=/usr/local/mysql --datadir=${DATA_DIR}/mysql${TMP_I}/data
done

# 环境变量设置
sed -i "/export PATH=/d" /etc/profile
echo "export PATH=/usr/local/mysql/bin:$PATH" >> /etc/profile 

# 启动mysql服务
echoLine
echoGoodLog "Start mysql."
if [ "${INSTALL_TIMES}" -le 1 ];then
    cp /usr/local/mysql/support-files/mysql.server /etc/rc.d/init.d/mysqld
    chmod +x /etc/rc.d/init.d/mysqld
    service mysqld start
else
    su -c "/usr/local/mysql/bin/mysqld_multi --log=${DATA_DIR}/mysql/muti.log start 1-${INSTALL_TIMES}" - mysql
fi

# mysql启动后的进程检查
echoLine
N=$(ps -ef | grep "datadir" | grep -v "grep" |wc -l)
if [ "$N" -eq $(expr ${INSTALL_TIMES} \* 2 ) ] ;then
    echoGoodLog "Mysql running."
else
    echoBadLog "Mysql install error, Please check..."
fi

echoLine
echoGoodLog "Script run done, But please exec command:    source /etc/profile    "
cleanRunLog ${RUN_LOG}