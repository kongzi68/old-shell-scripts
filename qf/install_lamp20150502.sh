#!/bin/bash
#auto install LAMP by source code 
#by colink on 2015-05-01

TARPATH='/soft/install/'
WGETPATH='/soft/lamp/'

#提前安装一些工具包和依赖包
echo -e "\033[32mInstall cmake and ntpdate servers,Please wait...\033[0m"
yum -y install  cmake  vim  wget  lrzsz  unzip man  ntpdate  gcc*  autoconf  libtool  python-devel  libXpm-devel  ncurses-devel  git
#初始化部分系统环境
#echo "alias vi='vim'" >>/root/.bashrc && source /root/.bashrc
echo -e "\033[32mNtpdate is running,Please wait...\033[0m"
ntpdate pool.ntp.org
sleep 3

#create download directory  
if [ ! -d ${WGETPATH} ];then
	echo -e "The ${WGETPATH} does not exist, Will create it. "
    mkdir -p ${WGETPATH}
fi
#Download LAMP install package
#wget --no-clobber -c --directory-prefix=${WGETPATH} "http://mirrors.sohu.com/php/php-5.6.8.tar.gz" "http://mirror.bit.edu.cn/mysql/Downloads/MySQL-5.7/mysql-5.7.6-m16.tar.gz" "http://mirror.bit.edu.cn/apache/httpd/httpd-2.4.12.tar.gz"

#Create tar directory  
if [ ! -d ${TARPATH} ];then
	echo -e "The ${TARPATH} does not exist, Will create it. "
    mkdir -p ${TARPATH}
fi
#TAR all install package
for i in `find ${WGETPATH} -maxdepth 1 -name "*.tar.gz"`
do
	tar -zxf "${i}" -C "${TARPATH}"
	if [ $? -eq 0 ];then
		echo -e "\033[32m解压文件${i}到${TARPATH}成功\033[0m"
	else
		exit
	fi
done

#find ${TARPATH} -maxdepth 1 -type d >/tmp/installlist.txt

#Apr define path variable
APR_DIR="${TARPATH}apr-1.5.1"
APR_PREFIX='/usr/local/apr'

#Apr-util define path variable
APR_UTIL_DIR="${TARPATH}apr-util-1.5.4"
APR_UTIL_PREFIX='/usr/local/apr-util'

#Httpd define path variable
HTTPD_DIR="${TARPATH}httpd-2.2.29"
HTTPD_PREFIX='/usr/local/apache2'

function Apache_install()
{
	cd ${APR_DIR}
	./configure --prefix=${APR_PREFIX} && make && make install
	if [ $? -eq 0 ];then
		echo -e "\033[32mThe apr was installed successfully.\033[0m"
		cd ${APR_UTIL_DIR}
	    ./configure  --prefix=${APR_UTIL_PREFIX} --with-apr=${APR_PREFIX} && make -j4 && make -j4 install		
		if [ $? -eq 0 ];then
			echo -e "\033[32mThe apr-util was installed successfully.\033[0m"
		    cd ${HTTPD_DIR}
		    ./configure --prefix=${HTTPD_PREFIX} --with-apr=${APR_PREFIX} --with-apr-util=${APR_UTIL_PREFIX} --enable-deflate=shared --enable-rewrite=shared --enable-static-support --with-mpm=worker && make -j4 && make -j4 install
		    if [ $? -eq 0 ];then
				echo -e "\033[32mThe httpd was installed successfully to ${HTTPD_PREFIX}\033[0m"
			else
				echo -e "\033[31mThe httpd is installed failed,Please check...\033[0m"
				exit
			fi
		else
	        echo -e "\033[31mThe apr-util is installed failed,Please check...\033[0m"
		    exit
		fi
	else
		echo -e "\033[31mThe apr is installed failed,Please check...\033[0m"
		exit
	fi
}

#Mysql define path variable
MYSQL_DIR="${TARPATH}mysql-5.6.23"
MYSQL_PREFIX='/usr/local/mysql2'
MYSQL_DATA_DIR='/data/mysql2'
#注意，如果上面修改了安装路径，请务必修改下面这条语句sed部分的mysql安装路径
MYSQL_STATUS_A=`ps -ef |grep mysql |awk 'NR==1 {print $9}' |sed 's/\/usr\/local\/mysql2\/bin\///g'`
#MYSQL_STATUS_B=``

function Mysql_install()
{
	cd ${MYSQL_DIR} && mkdir -p ${MYSQL_DATA_DIR} && cmake . -LH && cmake . -DCMAKE_INSTALL_PREFIX=${MYSQL_PREFIX} -DMYSQL_DATADIR=${MYSQL_DATA_DIR} -DWITH_INNOBASE_STORAGE_ENGINE=1 -DDEFAULT_CHARSET=utf8  -DDEFAULT_COLLATION=utf8_general_ci
	if [ $? -eq 0 ];then
		make -j4 && make -j4 install
    else
		echo -e "\033[31mThe Mysql is installed failed,Please check...\033[0m"
       exit
    fi
	cd ${MYSQL_PREFIX} ; groupadd mysql ; useradd -g mysql mysql ; chown -R root:mysql ${MYSQL_PREFIX} && chown -R mysql:mysql ${MYSQL_DATA_DIR} ;
	cp ${MYSQL_PREFIX}/support-files/my-default.cnf /etc/my.cnf && cp ${MYSQL_PREFIX}/support-files/mysql.server /etc/init.d/mysqld &&
	${MYSQL_PREFIX}/scripts/mysql_install_db --user=mysql --basedir=${MYSQL_PREFIX} --datadir=${MYSQL_DATA_DIR} &&
	echo "export PATH="\$PATH":${MYSQL_PREFIX}/bin/" >>/root/.bash_profile && source /root/.bash_profile && service mysqld restart 
	if [ "${MYSQL_STATUS_A}" = 'mysqld_safe' ];then
		echo -e "\033[32mThe Mysql was installed successfully to ${MYSQL_PREFIX}\033[0m"
		service mysqld stop ;
	else
	    echo -e "\033[31mThe Mysql is installed failed,Please check...\033[0m"
        exit
	fi
}

################################################
#INSTALL PHP AND GD
#PHP define path variable
PHP_DIR="${TARPATH}php-5.6.7"
PHP_PREFIX='/usr/local/php2'
#用i增长来判断php的扩展是否安装成功
i=0

#zlib define path variable
ZLIB_DIR="${TARPATH}zlib-1.2.8"
ZLIB_PREFIX='/usr/local/zlib'

#libxml2 define path variable
LIBXML2_DIR="${TARPATH}libxml2-2.9.2"
LIBXML2_PREFIX='/usr/local/libxml2'

#libmcrypt define path variable
LIBMCRYPT_DIR="${TARPATH}libmcrypt-2.5.8"
LIBMCRYPT_PREFIX='/usr/local/libmcrypt'

#Others define path variable
FREETYPE_DIR="${TARPATH}freetype-2.5.5"
JPEG9A_DIR="${TARPATH}jpeg-9a"
LIBPNG_DIR="${TARPATH}libpng-1.6.17"

#libgd define path variable
LIBGD_DIR="${TARPATH}libgd-gd-2.1.1"
LIBGD_PREFIX='/usr/local/libgd'

function php_install()
{
#install freetype
	cd ${FREETYPE_DIR} && ./configure && make -j4 && make -j4 install
	if [ $? -eq 0 ];then
        ((i++));
    else
		echo -e "\033[31mThe ${FREETYPE_DIR} is installed failed,Please check...\033[0m"
		exit
    fi
#install jpeg-9a
    cd ${JPEG9A_DIR} && ./configure && make -j4 && make -j4 install
    if [ $? -eq 0 ];then
        ((i++));
    else
        echo -e "\033[31mThe ${JPEG9A_DIR} is installed failed,Please check...\033[0m"
        exit
    fi
#install libpng
    cd ${LIBPNG_DIR} && ./configure && make -j4 && make -j4 install
    if [ $? -eq 0 ];then
        ((i++));
    else
        echo -e "\033[31mThe ${LIBPNG_DIR} is installed failed,Please check...\033[0m"
        exit
    fi
#install libgd
    cd ${LIBGD_DIR} &&
	cmake . -DCMAKE_INSTALL_PREFIX=${LIBGD_PREFIX} -DENABLE_FREETYPE=on -DENABLE_JPEG=on -DENABLE_PNG=on -DENABLE_XPM=on -DFREETYPE_INCLUDE_DIR_freetype2=/usr/local/include/freetype2 
    if [ $? -eq 0 ];then
		make -j4 && make -j4 install
	    if [ $? -eq 0 ];then
		    ((i++));
	    else
		    echo -e "\033[31mThe ${LIBGD_DIR} is installed failed,Please check...\033[0m"
			exit
	    fi
	else
		echo -e "\033[31mThe ${LIBGD_DIR} is installed failed,Please check...\033[0m"
		exit
	fi
#install libmcrypt
    cd ${LIBMCRYPT_DIR} &&
	./configure --prefix=${LIBMCRYPT_PREFIX} && make -j4 && make -j4 install
    if [ $? -eq 0 ];then
        ((i++));
    else
        echo -e "\033[31mThe ${LIBMCRYPT_PREFIX} is installed failed,Please check...\033[0m"
        exit
    fi
#install zlib
    cd ${ZLIB_DIR} && 
    ./configure --prefix=${ZLIB_PREFIX} && make -j4 && make -j4 install
    if [ $? -eq 0 ];then
        ((i++));
    else
        echo -e "\033[31mThe ${ZLIB_PREFIX} is installed failed,Please check...\033[0m"
        exit
    fi
#install libxml2
    cd ${LIBXML2_DIR} && 
    ./configure --prefix=${LIBXML2_PREFIX} && make -j4 && make -j4 install
    if [ $? -eq 0 ];then
        ((i++));
    else
        echo -e "\033[31mThe ${LIBXML2_PREFIX} is installed failed,Please check...\033[0m"
        exit
    fi
#判断i的值，如果i=7，将继续安装php，否则退出安装
#因为在安装php之前，安装了7个php的扩展包，所以i=7
    if [ $i -eq 7 ];then
		#install php server
		cd ${PHP_DIR} &&
		./configure --prefix=${PHP_PREFIX} --with-config-file-path=${PHP_PREFIX}/etc --with-apxs2=${HTTPD_PREFIX}/bin/apxs --with-pdo-mysql=mysqlnd --with-mysql=mysqlnd  --with-mysqli=mysqlnd --enable-mysqlnd --with-libxml-dir=${LIBXML2_PREFIX} --with-zlib-dir=${ZLIB_PREFIX} --with-mcrypt=${LIBMCRYPT_PREFIX} --with-gd  --with-jpeg-dir  --with-png-dir --with-xpm-dir --with-freetype-dir --enable-mbstring=all --enable-sockets --enable-soap
		if [ $? -eq 0 ];then
			make -j4 && make -j4 install
			if [ $? -eq 0 ];then
	            cp ${PHP_DIR}/php.ini-production ${PHP_PREFIX}/etc/php.ini
				#此处，如果php安装成功i=8的话，那就修改相应的配置文件
				((i++));
				echo -e "\033[32mThe PHP was installed successfully to ${PHP_PREFIX}\033[0m"
			else
				echo -e "\033[31mThe PHP is installed failed,Please check...\033[0m"
				exit
	        fi
		else
		    echo -e "\033[31mThe PHP is installed failed,Please check...\033[0m"
			exit
		fi
    else
        echo -e "\033[31mInstalled failed,Please check PHP's GD and so on...\033[0m"
        exit
    fi
#成功安装php之后，修改apache的配置文件，整合php等
    if [ $i -eq 8 ];then
		echo -e "\033[32mWill modify the configuration of Apache and PHP\033[0m"
		cp ${HTTPD_PREFIX}/conf/httpd.conf ${HTTPD_PREFIX}/conf/httpd.conf.bak
		echo "Addtype application/x-httpd-php  .php  .phtml" >> ${HTTPD_PREFIX}/conf/httpd.conf
		sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/g' ${HTTPD_PREFIX}/conf/httpd.conf
		sed -i 's/DirectoryIndex index.html/DirectoryIndex index.html index.php /g' ${HTTPD_PREFIX}/conf/httpd.conf
		#测试php是否全面安装成功
		if [ $? -eq 0 ];then
			echo -e "\033[32mIt's successfully, Will test the PHP... \033[0m"
			cat >${HTTPD_PREFIX}/htdocs/phpinfo.php <<EOF
<?php
phpinfo();
?>
EOF
			if [ $? -eq 0 ];then
				#启动apache服务
				${HTTPD_PREFIX}/bin/apachectl restart ;
				SERVER_IP=`ifconfig eth0 |grep Bcast |awk '{print $2}'|sed 's/addr://g'`
				echo -e "\033[32mYou can access http://${SERVER_IP}/phpinfo.php\033[0m"
			fi
		else
			echo -e "\033[31mThe PHP is installed failed,Please check...\033[0m"
		fi
	else
		echo -e "\033[31mThe PHP is installed failed,Please check...\033[0m"
		exit
	fi
}


PS3="Please select you will install server:"
select i in "Install_Apache" "Install_Mysql" "Install_PHP" "EXIT_INSTALL"
do
    case $i in
        Install_Apache)
            echo -e "\033[32mWill install Apache server.\033[0m"
            Apache_install
        ;;
        Install_Mysql)
            echo -e "\033[32mWill install Mysql server.\033[0m"
			Mysql_install
        ;;
        Install_PHP)
            echo -e "\033[32mWill install PHP server.\033[0m"
			php_install
        ;;
        EXIT_INSTALL) 
            exit
        ;;
    esac
done
