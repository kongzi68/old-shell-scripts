#!/bin/bash
# by colin on 2016-01-06
# revision on 2016-04-29
##################################
##脚本功能：
# 源码安装dns、nginx、php、memcached、gonet、mysql，并做相关的配置
#
##脚本说明：
#
##更新记录：
# 1、增加dns、nginx的配置文件
# 2、优化mysql、nginx、dns等安装的部分函数
# 3、增加安装gonet服务的功能函数
#
##################################
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/install_status.log'
[ -f ${RUN_LOG} ] && rm ${RUN_LOG}

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" | tee -a ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" | tee -a ${RUN_LOG}
}

echoLine(){
    sleep 3
    echo -e "\033[34m================LINE BETWEEN================\033[0m"
}

echoGoodLog "Now, Script: `basename $0` run."
##
# 路径与包变量定义
#
SCRIPTPWD=`pwd`
IPADDRETH0=`ifconfig eth0|grep "Bcast:"|awk '{print $2}'|awk -F: '{print $2}'` 
DIRPACKAGE="${SCRIPTPWD}/package/"
DIRCONFIG="${SCRIPTPWD}/configs/"
NGINXPACKAGENAME='nginx-1.8.0.tar.gz'
PHPPACKAGENAME='php-5.5.28.tar.gz'
MEMCACHED_PHP='memcache-3.0.8.tgz'
MYSQLPACKAGENAME='mysql-5.5.44.tar.gz'
##
# 检查shell环境
#
BASHENV=`ls -lh /bin/sh |grep "bash"|wc -l`
[ "${BASHENV}" -eq 0 ] && {
    echoBadLog "Please set shell scripts environment..."
    echoLine
    echoBadLog "Usage: ln -fs /bin/bash /bin/sh ; or Usage: dpkg-reconfigure dash"
    echoGoodLog "And re-run shell-scripts: sh `basename $0` , To install services."
    exit 0
}

##
# 检查/data分区是否挂载
#
checkDataPart(){
    DEFAULT_DISKPART='/data'
    DISKPART=${1:-$DEFAULT_DISKPART}
    mountpoint ${DISKPART}
    [ $? -eq 1 ] && {
        echoBadLog "${DISKPART} is not a mountpoint..."
        echoBadLog "`basename $0` exit, Please check..."
        exit
    }
    DISKDATATOTAL=`expr $(df -P|grep "${DISKPART}"|awk '{print $2}') - 104857600`    
    [ ${DISKDATATOTAL} -le 0 ] && {
        echoBadLog "${DISKPART} total size < 100GB, Please check..."
        read -n 1 -p "请确认${DISKPART}分区是否挂载正确，正确：Y|y ，输入N|n或其它将退出:" OK
        echo
        case ${OK} in
            Y|y) return 0;;
            *) echoBadLog "`basename $0` exit, Please check..."; exit;;
        esac
    }
}

##
# 判断IP是否符合标准规则
#
judgeIpAddr(){
    local $1 2>/dev/null
    TMP_TXT=/tmp/iptmp$$.txt
    echo $1 > ${TMP_TXT}
    IP_ADDR=`grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' ${TMP_TXT}`
    if [ ! -z "${IP_ADDR}" ];then
        local j=0
        for ((i=1;i<=4;i++))
        do
            local IP_NUM=`echo "${IP_ADDR}" |awk -F. "{print $"$i"}"`
            if [ "${IP_NUM}" -ge 0 -a "${IP_NUM}" -le 255 ];then
                ((j++))
            else
                return 1
            fi
        done
        if [ "$j" -eq 4 ];then
            read -n 1 -p "输入的IP地址是：${IP_ADDR} ,确认：Y|y；否则：R|r：" OK
            echo
            case ${OK} in
                Y|y) rm -rf ${TMP_TXT} ; return 0;;
                R|r) return 1;;
                *) return 1;;
            esac
        else
            return 1
        fi
    else
        return 1
    fi
}

##
# 输入IP
#
readRightIpAddr(){
    IP_TYPE=$1
    read -p "请输入${IP_TYPE}的IP地址值：" IP_ADDRS
    judgeIpAddr "${IP_ADDRS}"
    i=`echo $?`
    until [ "$i" -eq 0 ];do
        echoBadLog "你输入了错误的${IP_TYPE}IP地址为：${IP_ADDRS} ====>>>>"
        read -p "重新输入${IP_TYPE}的IP地址，请输入：" IP_ADDRS
        echo
        judgeIpAddr "${IP_ADDRS}"
        i=`echo $?`
    done
}

##
# 传参：$1服务的关键词，$2服务的端口号
#
checkInstallStatus(){
    KEY_SERVER=$1
    KEY_PORT=$2
    PIDSTATUS=`ps -ef |grep ${KEY_SERVER} |grep -v "grep"|wc -l`
    PORTSTATUS=`lsof -i :${KEY_PORT}|wc -l`
    if [ "${PIDSTATUS}" -ge 1 -a "${PORTSTATUS}" -ge 1 ];then
        echoGoodLog "Start ${KEY_SERVER} services is successfully."
        return 0
    else
        echoBadLog "Start ${KEY_SERVER} services was failed, Please check..."
        return 1
    fi
}

##
# 传参：$1是启动脚本文件，命名格式为：start_服务名
# e.g.: start_nginx
#
INSTALLTXT='/tmp/install_lnmp_result.txt'
[ -f ${INSTALLTXT} ] && rm ${INSTALLTXT}
setStartScripts(){
    INITSCRIPTSFILES=$1
    SCRIPTSNAME="${INITSCRIPTSFILES#start_}"
    cd ${SCRIPTPWD} && [ -e ./configs/${INITSCRIPTSFILES} ] && {
        cp ./configs/${INITSCRIPTSFILES} /etc/init.d/${SCRIPTSNAME}
        dos2unix /etc/init.d/${SCRIPTSNAME}
        chmod +x /etc/init.d/${SCRIPTSNAME}
        sysv-rc-conf --level 2345 ${SCRIPTSNAME} on 
    }
    echo "Start ${SCRIPTSNAME} services scripts: /etc/init.d/${SCRIPTSNAME}" >> ${INSTALLTXT}
    return 0
}

##
# 优化系统内核
#
setSystemKernel(){
    [ -f ${DIRCONFIG}sysctl.conf ] && {
        dos2unix ${DIRCONFIG}sysctl.conf
        cat ${DIRCONFIG}sysctl.conf > /etc/sysctl.conf
    }
    sed -i "/^ulimit/d" /etc/profile && echo "ulimit -SHn 65500" >> /etc/profile
    cat > /etc/security/limits.conf <<EOF
* soft nproc 65500
* hard nproc 65500
* soft nofile 65500
* hard nofile 65500
EOF
}

##
# 基本工具安装与设置
#
installTool(){
    echoGoodLog "Install tools."
    echoLine
    echo "nameserver 114.114.114.114" > /etc/resolv.conf
    PINGSTATUS=`ping -c 4 www.baidu.com |grep "packet loss"|awk -F, '{print $3}'|grep -Eo '[0-9]+'`
    [ "${PINGSTATUS}" -eq 0 ] || {
        echoBadLog "Please set the network for the system..."
        exit
    }
    # APTSOURCE='/etc/apt/sources.list'
    # [ -e ${APTSOURCE}.bak ] || cp ${APTSOURCE} ${APTSOURCE}.bak
    # cat > ${APTSOURCE} <<EOF
# deb http://mirrors.aliyun.com/ubuntu/ precise main restricted universe multiverse
# deb http://mirrors.aliyun.com/ubuntu/ precise-security main restricted universe multiverse
# deb http://mirrors.aliyun.com/ubuntu/ precise-updates main restricted universe multiverse
# deb http://mirrors.aliyun.com/ubuntu/ precise-proposed main restricted universe multiverse
# deb http://mirrors.aliyun.com/ubuntu/ precise-backports main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ precise main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ precise-security main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ precise-updates main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ precise-proposed main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ precise-backports main restricted universe multiverse
# EOF
    # apt-get update
    apt-get install unzip wget make cmake lrzsz lsof sysv-rc-conf dos2unix -y
    if [ $? -eq 0 ];then
        echoGoodLog "Install unzip wget make cmake lrzsz are successfully."
    else
        echoBadLog "Install unzip wget make cmake lrzsz were failed, Please check..."
        exit 1
    fi
}

setScriptCrontab(){
    SCRIPTSRUNDIR='/root/train_service/'
    [ -d ${SCRIPTSRUNDIR} ] || mkdir -p ${SCRIPTSRUNDIR}
    [ -d ${DIRCONFIG}scripts ] && { 
        cp -a ${DIRCONFIG}scripts/* ${SCRIPTSRUNDIR} && chmod +x ${SCRIPTSRUNDIR} -R
        cat >> /var/spool/cron/crontabs/root <<EOF
*/5 * * * * /root/train_service/system_status.sh -g >> /var/log/system_status_run_status.log  2>&1  &
0 * * * * /root/train_service/upload_record_gonet.sh  >> /var/log/cron_scripts_run.log  2>&1  &
EOF
    }
}

installBind9(){
    echoGoodLog "Install DNS services."
    echoLine
    apt-get install bind9 -y
    [ $? -eq 0 ] && {
        [ -d ${DIRCONFIG}zones ] && { 
            cp -a ${DIRCONFIG}zones /etc/bind/ || {
                echoBadLog "Set DNS config was failed, Please check..."
                return 1
            }
        }
        DNSCONFOPTIONS='/etc/bind/named.conf.options'
        [ -e ${DNSCONFOPTIONS}.bak ] || cp ${DNSCONFOPTIONS} ${DNSCONFOPTIONS}.bak
        cat > ${DNSCONFOPTIONS} <<EOF
options {
        directory "/var/cache/bind";
        forwarders {
                114.114.114.114;
        };
        allow-query-cache { any; };
        auth-nxdomain no;
        listen-on-v6 { any; };
};
EOF
        cat > /etc/bind/named.conf.local <<EOF
zone "wonaonao.com" {
        type master;
        file "/etc/bind/zones/wonaonao.com.db";
    };
zone "githubusercontent.com" {
        type master;
        file "/etc/bind/zones/githubusercontent.com.db";
    };
zone "hoobanr.com" {
        type master;
        file "/etc/bind/zones/hoobanr.com.db";
    };
zone "liziapp.com" {
        type master;
        file "/etc/bind/zones/liziapp.com.db";
    };
EOF
        #----------------------
        sed -i "s/LOCALIPADDR/${IPADDRETH0}/g" /etc/bind/zones/wonaonao.com.db
        readRightIpAddr 'WEB端'   # 调用IP输入函数，设置WEB的IP地址
        sed -i "s/WEBIPADDR/${IP_ADDRS}/g" /etc/bind/zones/wonaonao.com.db
        sed -i "s/WEBIPADDR/${IP_ADDRS}/g" /etc/bind/zones/hoobanr.com.db
        echo "Start DNS services scripts: /etc/init.d/bind9" >> ${INSTALLTXT}
        /etc/init.d/bind9 restart
        checkInstallStatus named 53
    }
}

#--------------------
NGINXPREFIX='/usr/local/nginx'
NGINXLOGDIR='/data/store/logs/www'
NGINXCACHEDIR='/var/cache/nginx'
DIRNGINX=${NGINXPACKAGENAME%.tar.gz}
installNginx(){
    echoGoodLog "Install nginx services."
    echoLine
    apt-get install libpcre3-dev openssl libssl-dev -y
    [ -d ${NGINXPREFIX} ] && rm ${NGINXPREFIX} -rf
    cd ${SCRIPTPWD} && [ -d ${DIRNGINX} ] && rm ${DIRNGINX} -rf
    tar -zxf ${DIRPACKAGE}${NGINXPACKAGENAME}
    cd ${DIRNGINX} && {
        ./configure --prefix=${NGINXPREFIX} --user=www-data --group=www-data \
        --conf-path=${NGINXPREFIX}/etc/nginx.conf --with-pcre --with-http_ssl_module \
        --with-http_realip_module --with-http_addition_module --with-http_sub_module \
        --with-http_dav_module --with-http_flv_module --with-http_gunzip_module \
        --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module \
        --with-http_stub_status_module --with-http_auth_request_module --error-log-path=${NGINXLOGDIR}/error.log \
        --http-log-path=${NGINXLOGDIR}/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=${NGINXCACHEDIR}/client_temp --http-proxy-temp-path=${NGINXCACHEDIR}/proxy_temp \
        --http-fastcgi-temp-path=${NGINXCACHEDIR}/fastcgi_temp --http-uwsgi-temp-path=${NGINXCACHEDIR}/uwsgi_temp \
        --http-scgi-temp-path=${NGINXCACHEDIR}/scgi_temp
        [ $? -eq 0 ] && make && make install
        [ -d ${NGINXCACHEDIR} ] || mkdir -p ${NGINXCACHEDIR}
    }
    cd ${NGINXPREFIX} && {
        cp -a ${DIRCONFIG}sites-enabled ./etc/ || {
            echoBadLog "Set Nginx sites-enabled config was failed, Please check..."
            return 1
        }
        DIRNAME=(
            /data/hls
            /data/www/train
            /data/www/traindata
        )
        for DIR in ${DIRNAME[@]}
        do
            if [ ! -d ${DIR} ];then
                mkdir -p ${DIR}
                chown -R www-data:www-data ${DIR}
            fi
        done
        [ -e ./etc/nginx.conf.bak ] || cp ./etc/nginx.conf ./etc/nginx.conf.bak
        cat > ./etc/nginx.conf <<EOF
user www-data;
worker_processes  auto;
error_log  ${NGINXLOGDIR}/error.log;
pid        /var/run/nginx.pid;
events {
    worker_connections  65535;
    multi_accept on;
    use epoll;
}
http {
    include       ${NGINXPREFIX}/etc/mime.types;
    access_log      ${NGINXLOGDIR}/access.log;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
        '\$status \$body_bytes_sent "\$http_referer" '
        '"\$http_user_agent" "\$http_x_forwarded_for"';
    server_names_hash_bucket_size 128;
    client_header_buffer_size 128k;
    large_client_header_buffers 4 128k;
    client_max_body_size 500M;
    sendfile on;
    tcp_nopush     on;
    types_hash_max_size 2048;
    keepalive_timeout 60;
    tcp_nodelay on;
    fastcgi_connect_timeout 300;
    fastcgi_send_timeout 300;
    fastcgi_read_timeout 300;
    fastcgi_buffer_size 256k;
    fastcgi_buffers 8 128k;
    fastcgi_busy_buffers_size 256k;
    fastcgi_temp_file_write_size 256k;
    server_tokens off;
    gzip  on;
    gzip_min_length  1k;
    gzip_buffers     4 16k;
    gzip_http_version 1.0;
    gzip_comp_level 2;
    gzip_types       text/plain application/x-javascript text/css application/xml application/json;
    gzip_vary on;
    gzip_disable "MSIE [1-6]\.(?!.*SV1)";
    include ${NGINXPREFIX}/etc/sites-enabled/*.conf;
}
EOF
    }
    #--------------------
    # INSTALLENVPATH是为了设置环境变量
    #
    INSTALLENVPATH=":${NGINXPREFIX}/sbin"
    setStartScripts start_nginx
    [ $? -eq 0 ] && {
        /etc/init.d/nginx start
        checkInstallStatus nginx 80
    }
}

#--------------------
PHPPREFIX='/usr/local/php5'
PHPLOGDIR='/data/store/logs/www'
DIRPHP=${PHPPACKAGENAME%.tar.gz}
installPHP(){
    echoGoodLog "Install PHP services."
    echoLine
    apt-get install gcc g++ curl autoconf automake autotools-dev \
    binutils libxml2 libxml2-dev libssl-dev libcurl4-openssl-dev \
    libjpeg-dev libpng12-dev bzip2 libbz2-dev libxpm-dev libfreetype6-dev \
    libedit-dev libxslt-dev libmcrypt-dev  libjpeg8-dev libgd2-xpm libfontconfig1 \
    libc6-dev  libtool zlib1g-dev manpages-dev  libreadline6-dev \
    shtool libevent-dev  libmemcached-dev -y
    [ -d ${PHPPREFIX} ] && rm ${PHPPREFIX} -rf
    cd ${SCRIPTPWD} && [ -d ${DIRPHP} ] && rm ${DIRPHP} -rf
    tar -zxf ${DIRPACKAGE}${PHPPACKAGENAME}
    cd ${DIRPHP} && {
        ./configure --prefix=${PHPPREFIX} --with-config-file-path=${PHPPREFIX}/etc \
        --with-pdo-mysql=mysqlnd --with-mysql=mysqlnd  --with-mysqli=mysqlnd --enable-mysqlnd \
        --with-libxml-dir=/usr/lib/ --with-zlib-dir --with-xpm-dir=/usr/lib/ --with-mcrypt=/usr/bin/libmcrypt-config \
        --with-gd --with-jpeg-dir --with-png-dir --with-xpm-dir --with-freetype-dir --enable-mbstring=all \
        --enable-sockets --enable-soap --enable-fpm --enable-bcmath --enable-calendar --enable-dba \
        --enable-exif --enable-ftp --enable-pcntl --enable-shmop --enable-sysvmsg --enable-sysvsem \
        --enable-sysvshm  --enable-wddx  --enable-opcache --enable-zip --with-xmlrpc --with-readline \
        --with-openssl --with-mhash --with-gettext --with-curl --with-bz2
        [ $? -eq 0 ] && make && make install
        [ $? -eq 0 ] || {
            echoBadLog "Install PHP services was failed, Please check..." 
            return 1
        }
        cp php.ini-production ${PHPPREFIX}/etc/php.ini
        sed -i '/;date.timezone/{s/;//g;s#=#= Asia/Shanghai#g}' ${PHPPREFIX}/etc/php.ini
        #cp ${PHPPREFIX}/etc/php-fpm.conf.default ${PHPPREFIX}/etc/php-fpm.conf
        cat > ${PHPPREFIX}/etc/php-fpm.conf <<EOF
[global]
pid = run/php-fpm.pid
error_log = ${PHPLOGDIR}/php-fpm.log
log_level = notice
emergency_restart_threshold = 60
emergency_restart_interval = 60s
 
[www]
user = www-data
group = www-data
listen = 127.0.0.1:9000
listen.owner = www-data
listen.group = www-data
pm=static
pm.max_children=50
pm.start_servers=20
pm.min_spare_servers=20
pm.max_spare_servers=50
pm.max_requests = 12000
pm.process_idle_timeout = 10s
request_terminate_timeout = 120
request_slowlog_timeout = 30s
slowlog = ${PHPLOGDIR}/php-fpm.log.slow
EOF
        ${PHPPREFIX}/sbin/php-fpm -t
        if [ $? -eq 0 ];then
            echoGoodLog "Install PHP services is successfully."
        else
            echoBadLog "Install PHP services was failed, Please check..."
        fi
    }
    ln -s ${PHPPREFIX}/bin/php /usr/bin/php
    #--------------------
    INSTALLENVPATH="${INSTALLENVPATH}:${PHPPREFIX}/bin"
    setStartScripts start_php-fpm
    [ $? -eq 0 ] && {
        /etc/init.d/php-fpm start
        checkInstallStatus php-fpm 9000
    }
}

#--------------------
DIRMEM=${MEMCACHED_PHP%.tgz}
installMemcached(){
    echoGoodLog "Install memcached services."
    echoLine
    apt-get install libsasl2-dev memcached -y
    cd ${SCRIPTPWD} && [ -d ${DIRMEM} ] && rm ${DIRMEM} -rf
    tar -zxf ${DIRPACKAGE}${MEMCACHED_PHP}
    cd ${DIRMEM} && {
        ${PHPPREFIX}/bin/phpize
        ./configure --enable-memcache --with-php-config=${PHPPREFIX}/bin/php-config --with-zlib-dir
        [ $? -eq 0 ] && make && make install    
        cat >> ${PHPPREFIX}/etc/php.ini <<EOF
[memcache]
extension_dir = "${PHPPREFIX}/lib/php/extensions/no-debug-non-zts-20121212/"
extension = memcache.so
EOF
    }
    echo "Start memcached services scripts: /etc/init.d/memcached" >> ${INSTALLTXT}
    /etc/init.d/memcached start
    checkInstallStatus memcached 11211
}

##
# 配置gonet服务
# AC设备厂商：alb：阿鲁巴，at：傲天，rj：锐捷
#
installGonet(){
    echoGoodLog "Install gonet services."
    echoLine
    GONETTYPE=(
        alb
        at
        rj
    )
    GONETPREFIX='/data/www/gonet/'
    [ -d ${GONETPREFIX} ] || mkdir -p ${GONETPREFIX}
    mkdir -p /data/store/logs/yjww && chmod 777 /data/store/logs/yjww
    readRightIpAddr 'AC设备'
    echoGoodLog "AC设备厂商：alb：阿鲁巴，at：傲天，rj：锐捷"
    PS3="Please select AC provider: "
    select i in ${GONETTYPE[@]}
    do
        case $i in
            ${GONETTYPE[0]})
                # alb
                cp -a ${DIRCONFIG}gonet/${GONETTYPE[0]}/* ${GONETPREFIX}
                sed -i "s/ACIPADDR/${IP_ADDRS}/g" ${GONETPREFIX}gonet.php
                [ $? -eq 0 ] && GONETINSTALLSTATUS=0 || GONETINSTALLSTATUS=1
                break 2
                ;;
            ${GONETTYPE[1]})
                # at
                cp -a ${DIRCONFIG}gonet/${GONETTYPE[1]}/* ${GONETPREFIX}
                sed -i -e "s/ACIPADDR/${IP_ADDRS}/g" -e "s/LOCALIPADDR/${IPADDRETH0}/g" ${GONETPREFIX}config.php
                [ $? -eq 0 ] && GONETINSTALLSTATUS=0 || GONETINSTALLSTATUS=1
                break 2
                ;;
            ${GONETTYPE[2]})
                # rj
                cp -a ${DIRCONFIG}gonet/${GONETTYPE[2]}/* ${GONETPREFIX}
                sed -i -e "s/ACIPADDR/${IP_ADDRS}/g" -e "s/LOCALIPADDR/${IPADDRETH0}/g" ${GONETPREFIX}define.php
                [ $? -eq 0 ] && GONETINSTALLSTATUS=0 || GONETINSTALLSTATUS=1
                break 2
                ;;
        esac
    done
    if [ "${GONETINSTALLSTATUS}" -eq 0 ];then
        echoGoodLog "Install gonet service is successfully."
    else
        echoBadLog "Install gonet service was failed, Please check..."
    fi
}

#--------------------
MYSQLPREFIX='/usr/local/mysql'
MYSQLLOGDIR='/var/log/mysql'
DIRMYSQL=${MYSQLPACKAGENAME%.tar.gz}
MYSQLUSER_GROUP='mysql'
MYSQLDATADIR='/data/mysql'
installMysql(){
    echoGoodLog "Install mysql services."
    echoLine
    groupadd ${MYSQLUSER_GROUP} && useradd ${MYSQLUSER_GROUP} -g ${MYSQLUSER_GROUP} -M -s /bin/false
    apt-get install cmake autoconf automake autotools-dev binutils libxml2 \
    libxml2-dev libssl-dev libncurses5-dev  libbison-dev  build-essential -y
    [ -d ${MYSQLPREFIX} ] && rm ${MYSQLPREFIX} -rf
    cd ${SCRIPTPWD} && [ -d ${DIRMYSQL} ] && rm ${DIRMYSQL} -rf
    tar -zxf ${DIRPACKAGE}${MYSQLPACKAGENAME}
    cd ${DIRMYSQL} && {
        cmake . -DCMAKE_INSTALL_PREFIX=${MYSQLPREFIX} \
        -DMYSQL_DATADIR=${MYSQLDATADIR} \
        -DMYSQL_UNIX_ADDR=${MYSQLDATADIR}/mysql.sock \
        -DSYSCONFDIR=${MYSQLPREFIX}/etc \
        -DMYSQL_USER=${MYSQLUSER_GROUP} \
        -DMYSQL_TCP_PORT=3306 \
        -DEXTRA_CHARSETS=all \
        -DDEFAULT_CHARSET=utf8 \
        -DDEFAULT_COLLATION=utf8_general_ci \
        -DWITH_MYISAM_STORAGE_ENGINE=1 \
        -DWITH_INNOBASE_STORAGE_ENGINE=1 \
        -DWITH_SSL=system \
        -DWITH_DEBUG=0 \
        -DWITH_READLINE=1 \
        -DWITH_EMBEDDED_SERVER=1 \
        -DENABLED_LOCAL_INFILE=1
        [ $? -eq 0 ] && make && make install 
        [ $? -eq 0 ] || {
            echoBadLog "Install mysql services was failed, Please check..." 
            return 1
        }
        cd ${MYSQLPREFIX} && {
            mkdir -p {etc,${MYSQLDATADIR},${MYSQLLOGDIR}}
            chown -R ${MYSQLUSER_GROUP}:${MYSQLUSER_GROUP} ${MYSQLPREFIX} ${MYSQLDATADIR} ${MYSQLLOGDIR}
            cat > ${MYSQLPREFIX}/etc/my.cnf <<EOF
[client]
port = 3306
socket=/tmp/mysql.sock

[mysqld_safe]
open-files-limit = 8192

[mysqld]
user = ${MYSQLUSER_GROUP}
pid-file = ${MYSQLDATADIR}/mysqld.pid
port = 3306
socket=/tmp/mysql.sock
datadir = ${MYSQLDATADIR}
basedir = ${MYSQLPREFIX}
log_error = ${MYSQLLOGDIR}/error.log
expire_logs_days = 10
back_log = 50
max_connections = 5000
max_connect_errors = 10
wait_timeout = 120
interactive_timeout = 120
table_open_cache = 2048
max_allowed_packet = 16M
binlog_cache_size = 1M
max_heap_table_size = 64M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
sort_buffer_size = 8M
join_buffer_size = 8M
thread_cache_size = 8
thread_concurrency = 8
query_cache_size = 64M
query_cache_limit = 2M
ft_min_word_len = 4
default-storage-engine = INNODB
thread_stack = 192K
sql-mode = NO_ENGINE_SUBSTITUTION
transaction_isolation = REPEATABLE-READ
tmp_table_size = 64M
log-bin = mysql-bin
binlog_format = mixed
max_binlog_size = 500M
slow_query_log
long_query_time = 2
server-id = 1
key_buffer_size = 32M
bulk_insert_buffer_size = 64M
myisam_sort_buffer_size = 128M
myisam_max_sort_file_size = 10G
myisam_repair_threads = 1
myisam-recover-options
innodb_flush_method = O_DIRECT
innodb_additional_mem_pool_size = 16M
innodb_file_per_table = 1
#innodb_buffer_pool_size = 2G
innodb_buffer_pool_size = 256M
innodb_data_home_dir =
innodb_data_file_path = ibdata1:10M:autoextend:max:1G
innodb_write_io_threads = 8
innodb_read_io_threads = 8
innodb_thread_concurrency = 16
innodb_flush_log_at_trx_commit = 1
innodb_log_buffer_size = 8M
innodb_log_file_size = 256M
innodb_log_files_in_group = 3
innodb_max_dirty_pages_pct = 90
innodb_lock_wait_timeout = 120

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 512M
sort_buffer_size = 512M
read_buffer = 8M
write_buffer = 8M

[mysqlhotcopy]
interactive-timeout
EOF
            #----------------
            ./scripts/mysql_install_db --user=${MYSQLUSER_GROUP} --basedir=${MYSQLPREFIX} --datadir=${MYSQLDATADIR} --defaults-file=./etc/my.cnf
            cp ./support-files/mysql.server /etc/init.d/mysql && chmod +x /etc/init.d/mysql
            sysv-rc-conf --level 2345 mysql on
        }
        echo "Start mysql services scripts: /etc/init.d/mysql" >> ${INSTALLTXT}
        INSTALLENVPATH="${INSTALLENVPATH}:${MYSQLPREFIX}/bin"
        /etc/init.d/mysql start
        INSTEADNUM=`echo ${IPADDRETH0}|awk -F. '{print $NF}'`
        MYSQLIPADDR=${IPADDRETH0%$INSTEADNUM}
        ${MYSQLPREFIX}/bin/mysql << EOF
        use mysql;
        delete from user where user='';
        grant all on rht_train.* to 'wifidb'@'${MYSQLIPADDR}%' identified by 'ZdEa_phN7bNQQq8';
        grant all on rht_tongji.* to 'wifidb'@'${MYSQLIPADDR}%';
        update user set password=password('password') where user='root';
        flush privileges;
EOF
        checkInstallStatus mysql 3306
        #ln -fs ${MYSQLDATADIR}/mysql.sock /tmp/mysql.sock    
        [ -f ${PHPPREFIX}/etc/php.ini ] && {
            sed -i "977d" ${PHPPREFIX}/etc/php.ini;
            A="pdo_mysql.default_socket='${MYSQLDATADIR}/mysql.sock'";
            sed -i "977i$A" ${PHPPREFIX}/etc/php.ini
            [ -f /etc/init.d/php-fpm ] && /etc/init.d/php-fpm restart
        }
    }
}

#传参，$1需要被安装服务-自定义的函数名
installServices(){
    SERVICESNAME=$1
    read -n 1 -p "Are you suer run ${SERVICESNAME#install} services：Y|y or N|n：" IS_INSTALL
    echo
    case ${IS_INSTALL} in
        Y|y) ${SERVICESNAME} ; return 0;;
        N|n) return 1;;
        *) return 1;;
    esac
}

#安装基础工具
installTool
#检查/data分区是否正确挂载
checkDataPart
#调用函数installServices,来提示是否安装DNS服务
installServices installBind9
installNginx 
installPHP
installMemcached
installServices installGonet
installServices installMysql
setScriptCrontab
setSystemKernel

UBUNTUPATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games'
sed -i "/export PATH=/d" /etc/profile
echo "export PATH=${UBUNTUPATH}${INSTALLENVPATH}" >> /etc/profile 
#. /etc/profile
source /etc/profile
echoLine
cat /tmp/install_lnmp_result.txt
echoLine
echo
echoGoodLog "Script run done, But please exec command:    source /etc/profile    "
echoGoodLog "请上传资源、web代码、gonet代码..."
echoGoodLog "脚本已优化内核，请手动重启系统，重启之后才能生效！"
echo
exit 0


