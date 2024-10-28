#!/bin/bash
# 用于备份官网web1服务器/data/www/目录下的网站

back_name="backup_$(date +%Y%m%d).tar.gz"
ssh -tt -i /IamUsername/.ssh/3jianhao IamUsername@iamIPaddress  <<-EOF
    cd /data && {
        find . -name "backup_*.tar.gz" -type f -delete
        tar -czf ${back_name} www/ --exclude=www/backup
    } 
    exit
EOF
scp -i /IamUsername/.ssh/3jianhao IamUsername@iamIPaddress:/data/${back_name} /data/backup_www_web1
find /data/backup_www_web1 -mtime +15 -name "backup_*.tar.gz" -delete
