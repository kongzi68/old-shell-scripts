#!/bin/bash
# 用于推送shell脚本到各虚拟机，通过n9e ibex 自愈脚本进行推送
export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:~/bin
cd /tmp/ && {
    [ -d scripts ] && rm -rf scripts
    if git clone https://jenkins:Iampassword@code.betack.com/devops/scripts.git;then
        echo "git下载scripts成功"
    else
        echo "git下载scripts失败，请检查..."
        exit
    fi
}

cd /tmp/scripts && {
    tar -czvf ops-libs.tar.gz ops-libs shell-scripts
    ls -lh
    [ -d /home/iamUserName/script/ ] || mkdir -p /home/iamUserName/script/
    mv -f ops-libs.tar.gz /home/iamUserName/script/
} || exit

cd /home/iamUserName/script/ && {
    tar -zxf ops-libs.tar.gz && rm -f ops-libs.tar.gz
    chown -R iamUserName:iamUserName ops-libs shell-scripts
    ls -lh ops-libs shell-scripts
} || exit

