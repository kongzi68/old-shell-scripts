#!/bin/bash
# by colin on 2022-07-29
## 用于清理iamIPaddress服务器上，类似/data1t/iamUserName-update-server/Index-Platform-STAGING下的文件
#+ 保留距离当前最新的文件

#+ 正则规则
REG='[0-9]{3,}'
#+ 删除符合条件的文件
for t_filename in $(ls | grep -E "${REG}" | sed -r "s/${REG}/bfdevops/g" | sort | uniq);do
    echo "文件模板名称：${t_filename}"
    
    ## 文件正则名称
    RE_FILENAME=$(echo ${t_filename} | sed "s/bfdevops/${REG}/g")
    echo "文件正则名称：${RE_FILENAME}"

    ## 最新的一个文件
    # TLAST_FILENAME=$(find . -regextype "posix-egrep" -regex ".*${RE_FILENAME}" | sort | tail -1)
    TLAST_FILENAME=$(find . -regextype "posix-egrep" -regex ".*${RE_FILENAME}" | xargs ls -rt | tail -1)
    LAST_FILENAME=$(basename ${TLAST_FILENAME})
    ls -lh ${LAST_FILENAME}
    echo "距离当前日期，最新的一个文件名称：${LAST_FILENAME}，即需要保留的文件"

    ## 找文件 RE_FILENAME ，但排除文件 LAST_FILENAME ，应该用正则匹配
    echo "++++++++++++++++++"
    find . -regextype "posix-egrep" -regex ".*${RE_FILENAME}" ! -name "${LAST_FILENAME}" | xargs ls -lh --full-time
    #+ 删除符合条件的文件
    # find . -regextype "posix-egrep" -regex ".*${RE_FILENAME}" ! -name "${LAST_FILENAME}" -ctime +3 -delete
    # find . -regextype "posix-egrep" -regex ".*${RE_FILENAME}" ! -name "${LAST_FILENAME}" -ctime +10 | xargs ls -lh --full-time
    #+ 再次查找文件
    echo "++++++++++++++++++++++++++++++++++++++"
    find . -regextype "posix-egrep" -regex ".*${RE_FILENAME}"  | xargs ls -lh --full-time
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
done

