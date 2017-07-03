#!/bin/bash
# 用于备份官网web1服务器/data/www/目录下的网站

back_name="backup_$(date +%Y%m%d).tar.gz"
ssh -tt -i /root/.ssh/3jianhao root@10.104.154.151  <<-EOF
    cd /data && {
        find . -name "backup_*.tar.gz" -type f -delete
        tar -czf ${back_name} www/ --exclude=www/backup
    } 
    exit
EOF
scp -i /root/.ssh/3jianhao root@10.104.154.151:/data/${back_name} /data/backup_www_web1
find /data/backup_www_web1 -mtime +15 -name "backup_*.tar.gz" -delete
