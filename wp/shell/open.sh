#!/bin/bash
#
# 每次开新服时，需要修改相应的SID
# 需要修改mysql语句前面的#注释，取消注释才能正确执行update语句

OLD_GS='10100211'
NEW_GS='10100212'

# 固定变量定义
LOG_FILE='./open_log.txt'
MAIL_FILE='./temp_mail_send.txt'
[ -f ${MAIL_FILE} ] && rm ${MAIL_FILE}

EMAIL=(
    15982363550@139.com
    kongxiaolin@windplay.cn
)

sendEmail(){
    dos2unix ${MAIL_FILE}
    for emailaddr in ${EMAIL[@]};do
        mail -s "$1" ${emailaddr} < ${MAIL_FILE}
        [ $? -eq 0 ] && echo "$(date +%F" "%T":"%N) Send email to ${emailaddr}." >> "${LOG_FILE}"
    done
}

/usr/bin/mysql -h10.221.124.144 -uroot -p'thisispassword' --default-character-set=utf8 > ${MAIL_FILE} << EOF
    use Login;
    # update t_gameserver_list set recommendstate=0 where sid=${OLD_GS};
    # update t_gameserver_list set mask=31,recommendstate=3 where sid=${NEW_GS};
    select sid,sname,state,mask,recommendstate from t_gameserver_list where sid in (${OLD_GS},${NEW_GS});
EOF

if [ $? -eq 0 ];then
    echo "$(date +%F" "%T":"%N) The server ${NEW_GS} is open successfully." >> ${MAIL_FILE}
    TXT1="Server is open successfully."
else
    echo "$(date +%F" "%T":"%N) The server ${NEW_GS} is open failed, Please check..." >> -a ${MAIL_FILE}
    TXT1="server is open failed"
fi

cat ${MAIL_FILE} >> ${LOG_FILE}
sendEmail "${TXT1}"
