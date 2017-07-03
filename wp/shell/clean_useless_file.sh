#!/bin/bash
# clean_useless_file.sh
# 用于清理导致inode被耗尽的垃圾邮件
# /var/spool/postfix/defer
# /var/spool/postfix/deferred
# /var/spool/postfix/maildrop

cd /var/spool/postfix && {
    for i in defer deferred maildrop;do
        AAA=$(find ${i} |wc -l)
        [ ${AAA} -gt 100 -a -d ${i} ] && {
            rm ${i}/* -rf
            # /etc/init.d/postfix restart
            /etc/init.d/postfix stop
        }
    done
}