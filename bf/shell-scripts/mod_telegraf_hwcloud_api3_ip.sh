#!/bin/bash
## 因telegraf插件net_response不能通过域名tcp探测
#+ 本脚本检测域名ip变化，修改telegraf配置文件，并重启telegraf服务
## 定时计划任务：修改 telegraf.conf 配置文件，检测api3端口情况
#+ */5 * * * * sh /opt/telegraf/mod_telegraf_hwcloud_api3_ip.sh > /dev/null 2>&1

TELEGRAF_CONFIG='/opt/telegraf/telegraf.conf'
NEW_API3_IP="$(nslookup api3.betack.com | grep Address | tail -1 | awk '{print $NF}')"
OLD_API3_IP="$(grep -A 2 net_response ${TELEGRAF_CONFIG} | grep address | tail -1 | awk -F[\":] '{print $2}')"

[ -z "${NEW_API3_IP}" ] && exit

if [ "${OLD_API3_IP}" != "${NEW_API3_IP}" ];then
    sed -i "s/${OLD_API3_IP}/${NEW_API3_IP}/g" ${TELEGRAF_CONFIG} && systemctl restart telegraf.service
fi
