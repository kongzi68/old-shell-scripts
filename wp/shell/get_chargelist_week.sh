#!/bin/bash

# 标记为 MOD 的，在部署到新环境时，需要修改
# MOD: 定义初始变量
#--------------------
DIR='/data/scripts/kyl'     # 目录最后一级不需要‘/’
COUNTRY='China'

#--------------------
cd ${DIR}
starttime=`date -d last-week +%Y-%m-%d`
endtime=`date  +%Y-%m-%d`
datetime=`date +%Y%m%d -d '7 days ago'`-` date +%m%d`
currenttime=`date "+%Y-%m-%d %H:%M:%S"`

# MOD: 不同国家的版本，需要发送的充值列表有变化
python get_ios_chargelist.py $starttime $endtime $datetime

# MOD: 需要发送的文件，务必注意文件名称的修改
mail_attachment="-a ${DIR}/ios_result_${datetime}.xls"

# MOD: 修改接收邮件者
EMAIL=(
    test1@windplay.cn
    kongxiaolin@windplay.cn
)

sendEmail(){
    for emailaddr in ${EMAIL[@]};do
        echo "${COUNTRY} ${starttime}--${endtime} recharge records" | mail -s "${COUNTRY} weekly recharge records" ${mail_attachment} ${emailaddr}
        [ $? -eq 0 ] && echo "$(date +%F" "%T":"%N) Send email to ${emailaddr}."
    done
    return 0
}

sendEmail
[ $? -eq 0 ] && echo "$currenttime  ${COUNTRY} ${starttime} -- ${endtime} 充值记录 发送成功！"
