#!/usr/bin/env bash
# by colin on 2018-01-24

INSTALL_CMD=$(find /usr/bin -name "yum" -o -name "apt-get")

check_fuc(){
    SCREEN=$(find /usr/bin -name "screen")
}

# frist check
check_fuc
if [[ ${SCREEN} == '' ]];then
    ${INSTALL_CMD} -y install screen
fi

# second check
check_fuc
if [[ ${SCREEN} == '/usr/bin/screen' ]];then
    echo "1"      # 在python中，0转成bool类型是False，1转成bool类型是True
    exit 0
else
    echo "0"
    exit 1
fi
