#!/bin/bash
# bak_mysql_db.sh
# by colin on 2023-06-16
# revision on 2023-06-16
##################################
##脚本功能：
#+ 增量拉取parquet文件
#+ /home/iamUserName/script/crontab/rsyncBarData_parquet.sh
#
##脚本说明：
#+ 效率太低，淘汰不用

## 输出绿色日志，表成功类型
echoGoodLog() {
    /bin/echo -e "\033[32m$(date +%F" "%T":"%N)|$(basename $0)|$*\033[0m"
}

## 输出红色日志，表失败类型
echoBadLog() {
    /bin/echo -e "\033[31m$(date +%F" "%T":"%N)|$(basename $0)|$*\033[0m"
}

#+ 清理上次的增量文件
cd /data2t/opt/bar_backend/data/iamUserName-code/ && rm * -rf && echoGoodLog "清理上次的增量文件完成."

#+ 通过上次的母版/data_bak/prod_106/iamUserName/iamUserName-code/获取增量文件清单
rsync -an --delete --out-format="%f" iamUserName@iamIPaddress:/alidata1/iamUserName-code/ /data_bak/prod_106/iamUserName/iamUserName-code/ > /tmp/need_list_file.txt
echoGoodLog "获取增量文件清单完成."

#+ 只同步增量清单中的文件到 /data2t/opt/bar_backend/data/iamUserName-code/
rsync -avP --include-from=/tmp/need_list_file.txt --exclude=/* iamUserName@iamIPaddress:/alidata1/iamUserName-code/ /data2t/opt/bar_backend/data/iamUserName-code/
echoGoodLog "拉取增量文件清单完成."

#+ 前面步骤完成后，更新 /data_bak/prod_106/iamUserName/iamUserName-code/ 到最新
rsync -avP iamUserName@iamIPaddress:/alidata1/iamUserName-code/ /data_bak/prod_106/iamUserName/iamUserName-code/
echoGoodLog "母版iamUserName-code更新到最新版完成."

#+ 检查 /data_bak/prod_106/iamUserName/iamUserName-code/ 缺少的文件夹，并创建
for item in $(cd /data_bak/prod_106/iamUserName/iamUserName-code/ && find . -type d);do
    DIR_ITEM=$(echo ${item} | awk -F'.' '{print $NF}')
    [ -d "/data2t/opt/bar_backend/data/iamUserName-code${DIR_ITEM}" ] || mkdir -p "/data2t/opt/bar_backend/data/iamUserName-code${DIR_ITEM}"
done

echoGoodLog 'done.'
