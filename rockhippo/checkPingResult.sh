#!/bin/bash
# check ping result
# by colin
# on 2016-06-08
########################################
# 功能说明：该脚本用于分析汇总成铁在线ping日志文件
#
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
LOGNAME='data/store/logs/record/ping.log'
GREPKEY='ping statistics'
WORKDIR='/tmp/checkPingResult'
TEMPPINGFILE="${WORKDIR}/temppingfile.txt"
CHECKRESULT="${WORKDIR}/temp_check_result.txt"

EMAIL=(
    colin@rockhippo.cn
    tony_ren@rockhippo.cn
    kevin@rockhippo.cn
)

TRAIN_CTZX=(
    k1364_k817:cdyd:ctzx_42
    k1364_k817:cdyd:ctzx_58
    k1364_k817:cdyd:ctzx_49
    k1364_k817:cdyd:ctzx_56
    k1364_k817:cdyd:ctzx_55
    k1364_k817:cdyd:ctzx_59
    k1364_k817:cdyd:ctzx_39
    k1364_k817:cdyd:ctzx_22
    k1364_k817:cdyd:ctzx_46
    k1364_k817:cdyd:ctzx_36
    k1364_k817:cdyd:ctzx_27
    k1364_k817:hrbdx:ctzx_26
    k1364_k817:hrbdx:ctzx_1
    k1364_k817:cddx:ctzx_51
    k1364_k817:cddx:ctzx_40
    k351_k352:cdyd:ctzx_2
    k351_k352:cdyd:ctzx_4
    k351_k352:cdyd:ctzx_5
    k351_k352:cdyd:ctzx_8
    k351_k352:cdyd:ctzx_9
    k351_k352:cdyd:ctzx_10
    k351_k352:cdyd:ctzx_12
    k351_k352:cdyd:ctzx_13
    k351_k352:cdyd:ctzx_14
    k351_k352:cdyd:ctzx_15
    k351_k352:cdyd:ctzx_16
    k351_k352:cdyd:ctzx_17
    k351_k352:cdyd:ctzx_19
    k1223_k1224:hrbdx:ctzx_33
    k1223_k1224:hrbdx:ctzx_34
    k1223_k1224:cddx:ctzx_41
    k1223_k1224:cddx:ctzx_47
    k1223_k1224:cddx:ctzx_54
    k1223_k1224:cdyd:ctzx_23
    k1223_k1224:cdyd:ctzx_38
    k1223_k1224:cdyd:ctzx_45
    k1223_k1224:cdyd:ctzx_48
    k1223_k1224:cdyd:ctzx_50
    k1223_k1224:cdyd:ctzx_60
)

sendEmail(){
    TEMP_EMAIL_FILES=$1
    [ $(wc -l ${TEMP_EMAIL_FILES}|awk '{print $1}') -eq 0 ] || { 
        for i in ${EMAIL[@]}
        do
            dos2unix -k ${TEMP_EMAIL_FILES} 
            mail -s "${HOSTNAME}: CTZX CHECK PING RESULT" ${i} < ${TEMP_EMAIL_FILES}
        done
    }
    [ -e ${TEMP_EMAIL_FILES} ] && rm ${TEMP_EMAIL_FILES}
}

[ -d ${WORKDIR} ] && rm ${WORKDIR} -rf
[ -f ${CHECKRESULT} ] && rm ${CHECKRESULT} 
mkdir -p ${WORKDIR}/temp/ && cd ${WORKDIR} && {
    for TARFILE in $(find /home/upload/ctzx/ct_tongji/ -name 'pinglog.tar.gz')
    do
        DEVNAME=$(echo "${TARFILE}"|awk -F/ '{print $(NF-1)}')
        for T_DEV_ID in ${TRAIN_CTZX[@]}
        do
            TRAIN_ID=$(echo ${T_DEV_ID}|awk -F: '{print $1}')
            CARD_ID=$(echo ${T_DEV_ID}|awk -F: '{print $2}')
            DEV_ID=$(echo ${T_DEV_ID}|awk -F: '{print $3}')
            [ ${DEVNAME} = ${DEV_ID} ] && break
        done
        TARFILENAME=$(echo "${TARFILE}"|awk -F/ '{print $NF}')
        cp ${TARFILE} .
        tar -zxf ${TARFILENAME} && rm -f ${TARFILENAME}
        ##
        # 加-n参数添加行号，-A 2取出的数据，有遇到第三行为空的情况
        #
        grep -n -A 2 "${GREPKEY}" ${LOGNAME}|grep -v "${GREPKEY}"|sed -r 's/[^0-9\.]+/ /g'|sed 's/^ //g'|grep -v "^$" |awk '{$1="";print $0}' > ${TEMPPINGFILE}
        PACKETS_TRANSMITTED=$(sed -n 'p;n' ${TEMPPINGFILE}|awk '{sum+=$1} END {print sum}')
        PACKETS_RECEIVED=$(sed -n 'p;n' ${TEMPPINGFILE}|awk '{sum+=$2} END {print sum}')
        PACKET_LOSS=$(sed -n 'p;n' ${TEMPPINGFILE}|awk '{sum+=$3} END {print sum/NR}')
        PING_MIN=$(sed -n 'n;p' ${TEMPPINGFILE}|grep -vE "([0-9]{1,3}\.){3}" |awk '{print $1}' |sort -n|uniq|sed -n '1p')
        PING_AVG=$(sed -n 'n;p' ${TEMPPINGFILE}|grep -vE "([0-9]{1,3}\.){3}"|awk '{sum+=$2} END {print sum/NR}')
        PING_MAX=$(sed -n 'n;p' ${TEMPPINGFILE}|grep -vE "([0-9]{1,3}\.){3}" |awk '{print $3}' |sort -n|uniq|sed -n '$p')
        echo "${PACKETS_TRANSMITTED},${PACKETS_RECEIVED},${PACKET_LOSS},${PING_MIN},${PING_AVG},${PING_MAX}" >> ${WORKDIR}/temp/${TRAIN_ID}_a_${CARD_ID}
        [ -f ${TEMPPINGFILE} ] && rm ${TEMPPINGFILE}
    done
}

groupPingResult(){
    CHECKFILENAME=$1
    PACK_SENT_ALL=$(awk -F, '{sum+=$1} END {print sum}' ${CHECKFILENAME})
    PACK_RECEIVE_ALL=$(awk -F, '{sum+=$2} END {print sum}' ${CHECKFILENAME})
    PACK_LOSS_AVG=$(printf %0.2f $(awk -F, '{sum+=$3} END {print sum/NR}' ${CHECKFILENAME}))
    PING_MIN_AVG=$(printf %0.2f $(awk -F, '{sum+=$4} END {print sum/NR}' ${CHECKFILENAME}))
    PING_AVG_AVG=$(printf %0.2f $(awk -F, '{sum+=$5} END {print sum/NR}' ${CHECKFILENAME}))
    PING_MAX_AVG=$(printf %0.2f $(awk -F, '{sum+=$6} END {print sum/NR}' ${CHECKFILENAME}))
    ALL_RESULT="${PACK_SENT_ALL},${PACK_RECEIVE_ALL},${PACK_LOSS_AVG},${PING_MIN_AVG},${PING_AVG_AVG},${PING_MAX_AVG}"
}

cd ${WORKDIR}/temp/ && {
    for i in $(find . -name "*_a_*")
    do
        TRAINCARD=$(echo $i | awk -F/ '{print $NF}')
        groupPingResult ${TRAINCARD}
        TRAINCARD_NAME=$(echo ${TRAINCARD} | sed 's/_a_/,/g')
        echo "${TRAINCARD_NAME},${ALL_RESULT}" >> ${CHECKRESULT}
        [ -f ${TRAINCARD} ] && rm ${TRAINCARD} -f
    done
    cat ${CHECKRESULT}|sort -n -t, -k5 > ${WORKDIR}/check_result.txt
    sed -i '1i车次,卡类型,总发送包,总接收包,丢失率,PING_MIN,PING_AVG,PING_MAX' ${WORKDIR}/check_result.txt
    #cat ${CHECKRESULT}|sort -n -t, -k5 > ${WORKDIR}/t_check_result.txt
    #sed -i '1i车次,卡类型,总发送包,总接收包,丢失率,PING_MIN,PING_AVG,PING_MAX' ${WORKDIR}/t_check_result.txt
    #column -s, -t ${WORKDIR}/t_check_result.txt > ${WORKDIR}/check_result.txt
    #[ -f ${WORKDIR}/t_check_result.txt ] && rm ${WORKDIR}/t_check_result.txt
    [ -f ${CHECKRESULT} ] && rm ${CHECKRESULT}
    sendEmail ${WORKDIR}/check_result.txt
}