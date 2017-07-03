#!/bin/sh

DIR='/data/tmp/scripts/'
SCRIPT_NAME='jybus_scripts.sh'
[ -d ${DIR} ] || mkdir -p ${DIR}
cd ${DIR} && {
    if [ -e ${SCRIPT_NAME} ];then
        sh ${SCRIPT_NAME} && rm ${SCRIPT_NAME}
    else
        exit
    fi
}






