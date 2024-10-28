#!/bin/bash

cd /home/colin && {
    rm *.sql ; tar -zxvf dump.tar.gz
    for i in $(ls *.sql)
    do
        mysql -uIamUsername -ppassword --default-character-set=utf8 rht_train  < $i
        [ $? -eq 0 ] && echo "导入$i成功" || echo "导入$i失败，请检查……"
    done
    [ -f dump.tar.gz ] && rm dump.tar.gz
}
