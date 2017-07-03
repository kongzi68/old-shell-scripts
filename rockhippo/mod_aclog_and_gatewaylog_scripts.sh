#!/bin/bash
#mod shell scripts
#修改aclog与gatewaylog脚本的本地存储路径

DATADISK=`df -hP|awk '{print $6}'|grep -w "data" |wc -l`
[ ${DATADISK} -eq 1 ] && { 
    cd /root/ && {
        for i in `find . -maxdepth 1 -type f -name "*.sh"`
        do
            NEED_MOD_FILE=`echo $i |awk -F/ '{print $NF}'`
            STATUS1=`echo ${NEED_MOD_FILE}|grep -E "gateway_backup_and_upload|aclog_backup_and_upload"|wc -l`
            [ ${STATUS1} -eq 1 ] && {
                echo "将要修改的脚本名称如下：${NEED_MOD_FILE}" 
                sed -ri "/^log_name=/i HOSTNAME=\`echo \$(hostname) |awk -F- '{print \$3}'\`" ${NEED_MOD_FILE} 
                sed -ri "/^lcd_dir=/s/\/mntlog\//\/data\/\${HOSTNAME}_log\//1" ${NEED_MOD_FILE}
                echo "============================"
                grep "#define the ftp client" -A 6 -B 2 ${NEED_MOD_FILE}
                echo "============================"
                echo
            }
        done
    }
} || echo "没有/data分区，无需修改"
