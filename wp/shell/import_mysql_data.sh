#!/bin/bash

###########################
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
RUN_LOG='/var/log/scripts_run_status.log'

echoGoodLog(){
    echo -e "\033[32m`date +%F" "%T":"%N` $*\033[0m" | tee -a ${RUN_LOG}
}

echoBadLog(){
    echo -e "\033[31m`date +%F" "%T":"%N` $*\033[0m" | tee -a ${RUN_LOG}
}

###########################
M_USER='root'
M_PASSWORD='thisispassword'
DB_NAME='OSS_record'
TB_NAME='AddCash'
E_TB_NAME='AddCash_bak20160809'
DB_SOCKET='/data/mysql2/data/mysql.sock'
##
# 设置需要导出数据的范围
#+ 比如：AddCash_bak20160809表有11亿条数据，只导出8.5亿至11亿条。
#+ 则，E_START=85000，E_END=118042
#+ 因为每次导出一万条数据，118042*10000刚好大于该表的记录条数1180413704。
#
E_START='85000'
E_END='118042'

# M_USER='root'
# M_PASSWORD='123456'
# DB_NAME='jfedu'
# TB_NAME='xstest_t'
# E_TB_NAME='xstest'
# DB_SOCKET='/data/mysql/data/mysql.sock'


BAK_DIR='/data/data_bak/'
[ -d ${BAK_DIR} ] || mkdir ${BAK_DIR}
chown mysql:mysql ${BAK_DIR}

# for i in $(seq 0 850);
# do
#     START_VALUES="$(expr $i \* 10000 )"
#     FILE_NAME="$(expr $i + 1)"
#     mysqldump -uroot -p123456 --default-character-set=utf8 jfedu xstest --where "1=1 limit ${START_VALUES},10000" |gzip > /data/${FILE_NAME}.sql.gz
# done

# use OSS_record;
# 850000000 8.5亿

# for i in $(seq 0 850)
# do
#     START_VALUES="$(expr $i \* 10000 )"
#     FILE_NAME="$(expr $i + 1)"
#     mysql -uroot -p123456 <<EOF
#         use jfedu;
#         SELECT * INTO OUTFILE '/data/${FILE_NAME}_10000.sql' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' FROM xstest limit ${START_VALUES},10000;
# EOF
#     tar -czf /data/${FILE_NAME}_10000.tar.gz --remove-files /data/${FILE_NAME}_10000.sql
# done

for i in $(seq ${E_START} ${E_END})
do
    START_TIME=$(date +%s)
    START_VALUES="$(expr $i \* 10000 )"
    FILE_NAME="$(expr $i + 0)"
    /usr/local/mysql/bin/mysql -u${M_USER} -p${M_PASSWORD} -S ${DB_SOCKET} --default-character-set=utf8 <<EOF
        use ${DB_NAME};
        SELECT * INTO OUTFILE '${BAK_DIR}${FILE_NAME}.sql' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' FROM ${E_TB_NAME} limit ${START_VALUES},10000;
EOF
    if [ $? -eq 0 ];then
        echoGoodLog "Export ${BAK_DIR}${FILE_NAME}.sql data successfully."
    else
        echoBadLog "Export the ${BAK_DIR}${FILE_NAME}.sql data failure." 
        exit
    fi
    #tar -czf ${BAK_DIR}${FILE_NAME}.tar.gz --remove-files ${BAK_DIR}${FILE_NAME}.sql
    NEED_TIME=$(expr $(date +%s) - ${START_TIME})
    echoGoodLog "Export ${BAK_DIR}${FILE_NAME}.sql data: ${NEED_TIME}s, about: $(expr ${NEED_TIME} / 60)m$(expr ${NEED_TIME} % 60)s."
    ##
    # import data
    #
    START_TIME=$(date +%s)
    /usr/local/mysql/bin/mysql -u${M_USER} -p${M_PASSWORD} -S ${DB_SOCKET} --default-character-set=utf8 <<EOF
        use ${DB_NAME};
        LOAD DATA LOCAL INFILE '${BAK_DIR}${FILE_NAME}.sql' INTO TABLE ${TB_NAME} FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n';
EOF
    if [ $? -eq 0 ];then
        echoGoodLog "Import ${BAK_DIR}${FILE_NAME}.sql data successfully."
    else
        echoBadLog "Import the ${BAK_DIR}${FILE_NAME}.sql data failure." 
        exit
    fi
    NEED_TIME=$(expr $(date +%s) - ${START_TIME})
    echoGoodLog "Import ${BAK_DIR}${FILE_NAME}.sql data: ${NEED_TIME}s, about: $(expr ${NEED_TIME} / 60)m$(expr ${NEED_TIME} % 60)s."
    [ -f ${BAK_DIR}${FILE_NAME}.sql ] && rm ${BAK_DIR}${FILE_NAME}.sql -f
    # [ $i -eq 85003 ] && break
done
