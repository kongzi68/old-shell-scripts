#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SRC='/data/www/traindata/imgs/'
DES='/data/www/traindata/imgs/'
IPARRAY=(
    10.22.1.141:220
    10.173.128.85:8888
    10.43.71.166:8888
    10.43.75.92:8888
    10.43.236.136:8888
    10.98.156.76:8888
    10.98.22.51:8888
    10.98.22.12:8888
    10.43.46.23:8888
)

inotifywait -mrq --timefmt '%d/%m/%y-%H:%M' --format '%T %w%f' -e modify,delete,create,attrib ${SRC} | while read file
do
    for IPPORT in ${IPARRAY[@]}
    do
        IP=$(echo "${IPPORT}" | awk -F: '{print $1}')
        PORT=$(echo "${IPPORT}" | awk -F: '{print $2}')
        rsync -avzP "-e ssh -p ${PORT}" --delete ${SRC}  root@${IP}:${DES} >> /dev/null 2>&1
    done
done
