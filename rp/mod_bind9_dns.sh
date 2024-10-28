#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

addBindConf(){
    cat >> /etc/bind/named.conf.local <<EOF

zone "liziapp.com" {
        type master;
        file "/etc/bind/zones/liziapp.com.db";
        };
EOF
    cat > /etc/bind/zones/liziapp.com.db <<\EOF
$TTL    86400
liziapp.com. IN SOA dns.liziapp.com. admin.liziapp.com. (
                                                                20060814
                                                                28800
                                                                3600
                                                                604800
                                                                38400 );

liziapp.com. IN NS dns.liziapp.com.
liziapp.com. IN MX 10 mta.liziapp.com.

push IN A iamIPaddress
* IN A iamIPaddress
EOF
}

[ -d /etc/bind ] && {
    sed -i '/imga/{P;s/imga/appimg/g}' /etc/bind/zones/wonaonao.com.db
    sed -i '/appm/{P;s/appm/app/g}' /etc/bind/zones/wonaonao.com.db
    addBindConf && service bind9 restart && echo "Restart bind9 is successfully..." >> /tmp/addconfg_tmp.txt
}
#------------------

addNginxConf(){
    cat > ${1}/app_wonaonao_com.conf <<\EOF
server {
        listen       80;
        listen       81;
        server_name  app.wonaonao.com;
        IamUsername   /data/www/train/public/app;
        access_log /data/store/logs/www/app_wonaonao_access.log;
        error_log /data/store/logs/www/app_wonaonao_error.log notice;
        location = /favicon.ico {
        try_files $uri =204;
        log_not_found off;
        access_log off;
        }
        location / {
                index index.php index.htm index.html;
        }
        location /imgs/ {
                alias /data/www/traindata/imgs/;
                autoindex on;
        }
        location /files/ {
                alias /data/www/traindata/files/;
        }
        location /apps/ {
                alias /data/www/traindata/imgs/apps/;
        }
        error_page 404 500 502 503 504  /static/404.html;
        include /data/www/train/protected/configs/app_urls.conf;
        location ~ \.php$ {
                fastcgi_pass   iamIPaddress:9000;
                fastcgi_index  index.php;
                fastcgi_param  SCRIPT_FILENAME    $document_IamUsername$fastcgi_script_name;
                include        fastcgi_params;
                #include                        fastcgi.conf;
        }
        location ~ /\.ht {
                deny  all;
        }
}
EOF
    cat > ${1}/appimg_wonaonao_com.conf <<\EOF
server {
        listen       80;
        listen       81;
        server_name  appimg.wonaonao.com;
        IamUsername   /data/www/train/public/app/;
        access_log /data/store/logs/www/appimg_wonaonao_access.log;
        error_log /data/store/logs/www/appimg_wonaonao_error.log;
        location = /favicon.ico {
        try_files $uri =204;
        log_not_found off;
        access_log off;
        }
        error_page 404 500 502 503 504  /static/404.html;
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

[ -f /tmp/addconfg_tmp.txt ] && cat /tmp/addconfg_tmp.txt && rm /tmp/addconfg_tmp.txt
