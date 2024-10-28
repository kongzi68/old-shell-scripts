#!/bin/bash
# get mysql and linux system status

INTERVAL=5
PREFIX=$INTERVAL-sec-status
RUNFILE='/var/log/running'
/usr/local/mysql/bin/mysql -uIamUsername -pgame@t6game -S /data/mysql1/data/mysql.sock -e 'SHOW GLOBAL VARIABLES' >> mysql-variables
while test -e $RUNFILE; do
    file=$(date +%F_%I)
    sleep=$(date +%s.%N | awk "{print $INTERVAL - (\$1 % $INTERVAL)}")
    sleep $sleep
    ts="$(date +'TS %s.%N %F %T')"    
    loadavg="$(uptime)"
    echo "$ts $loadavg" >> $PREFIX-${file}-status
    /usr/local/mysql/bin/mysql -uIamUsername -pgame@t6game -S /data/mysql1/data/mysql.sock -e 'SHOW GLOBAL VARIABLES' >> $PREFIX-${file}-status & 
    echo "$ts $loadavg" >> $PREFIX-${file}-innodbstatus
    /usr/local/mysql/bin/mysql -uIamUsername -pgame@t6game -S /data/mysql1/data/mysql.sock -e 'SHOW ENGINE INNODB STATUS\G' >> $PREFIX-${file}-innodbstatus &
    echo "$ts $loadavg" >> $PREFIX-${file}-processlist
    /usr/local/mysql/bin/mysql -uIamUsername -pgame@t6game -S /data/mysql1/data/mysql.sock -e 'SHOW FULL PROCESSLIST\G' >> $PREFIX-${file}-processlist &
    echo $ts
done
echo Exiting because $RUNFILE does not exits.

