#!/bin/bash
#mod shell scripts
#修改脚本的ftp函数的代码部分

cd /root/ && {
    for i in `find . -maxdepth 1 -type f -name "*.sh"`
    do
        NEED_MOD_FILE=`echo $i |awk -F/ '{print $NF}'`
        STATUS1=`grep -E "send_to_ftp|send_log|send_gonet_log" "${NEED_MOD_FILE}"|wc -l`
        [ ${STATUS1} -gt 0 ] && {
            echo "将要修改的脚本名称如下：${NEED_MOD_FILE}" 
            sed -i -e "/ftp -i/s/-i.*n/-ivn/g" -e "/ftp -i/s/2>/>/g" ${NEED_MOD_FILE} 
            [ $? -eq 0 ] && echo "1 mod successfully." || echo "1 mod failed."
            sed -i "/log_count=/s/cat/grep \"^226\"/g" ${NEED_MOD_FILE}
            [ $? -eq 0 ] && echo "2 mod successfully." || echo "2 mod failed."
            FILE_STATUS=`echo ${NEED_MOD_FILE}|grep "upload_record_gonet"|wc -l`
            if [ ${FILE_STATUS} -eq 1 ];then
                sed -i "/\${log_count} -eq 0/s/-eq 0/-eq 1/g" ${NEED_MOD_FILE}
                [ $? -eq 0 ] && echo "3 mod successfully." || echo "3 mod failed."
            else
                sed -i "/ftp_stat=0/s/-eq 0/-eq 1/g" ${NEED_MOD_FILE}
                [ $? -eq 0 ] && echo "3 mod successfully." || echo "3 mod failed."
            fi
        }
    done
}

