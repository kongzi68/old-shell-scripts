#!/bin/bash
cd /data/script/ && {
    for SCRIPTS_FILE in $(grep "pengjianjun@windplay.cn" -R /data/script/)
    do
        SCRIPTS_NAME=$(echo "${SCRIPTS_FILE}" | awk -F':' '{print $1}' )
        SED_CONDITION=$(echo "${SCRIPTS_FILE}" | awk -F[:=,] '{print $2}')
        [ -f ${SCRIPTS_NAME} ] && sed -i "/${SED_CONDITION}/s/pengjianjun/zhangsan/g" ${SCRIPTS_NAME} || continue
        [ $? -eq 0 ] && echo -e "\033[32mThe ${SCRIPTS_NAME} has been successfully modified.\033[0m" || echo -e "\033[31mThis ${SCRIPTS_NAME} changes unsuccessful, Please check ......\033[0m"
    done
}

# 直接在shell命令行执行，无格式 
cd /data/script/ && for SCRIPTS_FILE in $(grep "pengjianjun@windplay.cn" -R /data/script/);do SCRIPTS_NAME=$(echo "${SCRIPTS_FILE}" | awk -F':' '{print $1}' ); SED_CONDITION=$(echo "${SCRIPTS_FILE}" | awk -F[:=,] '{print $2}'); [ -f ${SCRIPTS_NAME} ] && sed -i "/${SED_CONDITION}/s/pengjianjun/zhangsan/g" ${SCRIPTS_NAME} || continue; [ $? -eq 0 ] && echo -e "\033[32mThe ${SCRIPTS_NAME} has been successfully modified.\033[0m" || echo -e "\033[31mThis ${SCRIPTS_NAME} changes unsuccessful, Please check ......\033[0m"; done