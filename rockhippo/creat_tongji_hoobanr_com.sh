#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

addBindConf(){
    IPADDR=$(ifconfig eth0|grep "inet addr:"|awk '{print $2}'|awk -F: '{print $2}')
    cat >> /etc/bind/named.conf.local <<EOF
zone "hoobanr.com" {
        type master;
        file "/etc/bind/zones/hoobanr.com.db";
        };
EOF
    cat > /etc/bind/zones/hoobanr.com.db <<\EOF
$TTL    86400
hoobanr.com. IN SOA dns.hoobanr.com. admin.hoobanr.com. (
                                                                20060814
                                                                28800
                                                                3600
                                                                604800
                                                                38400 );

hoobanr.com. IN NS dns.hoobanr.com.
hoobanr.com. IN MX 10 mta.hoobanr.com.

tongji IN A ${IPADDR}
* IN A ${IPADDR}
EOF
}

[ -d /etc/bind ] && addBindConf && service bind9 restart && echo "Restart bind9 is successfully..." >> /tmp/addconfg_tmp.txt
#------------------

addNginxConf(){
    cat > ${1}/tongji_hoobanr_com.conf <<\EOF
server {
        listen       80;
        listen       81;
        server_name  tongji.hoobanr.com;

        root   /data/www/train/public/tongji/;

        access_log /data/store/logs/www/tongji_hoobanr_access.log;
        error_log /data/store/logs/www/tongji_hoobanr_error.log;

        location = /favicon.ico {
        try_files $uri =204;
        log_not_found off;
        access_log off;
        }
        location / {
                index index.php index.htm index.html;
        }
        error_page 404 500 502 503 504  /static/404.html;
        location ~ \.php$ {
                fastcgi_pass   127.0.0.1:9000;
                fastcgi_index  index.php;
                fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;
                include        fastcgi_params;
        }
        location ~ /\.ht {
                deny  all;
        }
}
EOF
}

if [ -d /etc/nginx/sites-enabled ];then
    NGINXPATH='/etc/nginx/sites-enabled'
    addNginxConf ${NGINXPATH}
    service nginx restart && echo "Restart nginx is successfully..." >> /tmp/addconfg_tmp.txt
else
    [ -d /usr/local/nginx/etc/sites-enabled ] && {
        NGINXPATH='/usr/local/nginx/etc/sites-enabled'
        addNginxConf ${NGINXPATH}
        /etc/init.d/nginx restart && echo "Restart nginx is successfully..." >> /tmp/addconfg_tmp.txt
    }
fi

cat /tmp/addconfg_tmp.txt
[ -f /tmp/addconfg_tmp.txt ] && rm /tmp/addconfg_tmp.txt








