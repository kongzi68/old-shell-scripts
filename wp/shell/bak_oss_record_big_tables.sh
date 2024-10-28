#!/bin/bash

ARRY_TABLES=(
    AddCash_bak20160809
    AddItem_old
    AllianceTrain_bak20160809
    OSSReduceCash_bak20160809
    ReduceCash_bak20160809
    RemoveItem_20160809
    Train_bak20160809
    VIPShopBuy_bak20160809
    WipeOut_bak20160809
)

cd /data/db_backup/bak_oss_record_20160809 && {
    for item in ${ARRY_TABLES[@]};do
        /usr/local/mysql/bin/mysqldump -h'iamIPaddress' -uIamUsername -p'thisispassword' -P3307 \
        --default-character-set=utf8 OSS_record ${item} | gzip > ${item}.sql.gz
        if [ $? -eq 0 ];then
            echo "Backup ${item}.sql.gz succesed."
        else
            echo "Backup ${item}.sql.gz filed..."
        fi
    done
}

