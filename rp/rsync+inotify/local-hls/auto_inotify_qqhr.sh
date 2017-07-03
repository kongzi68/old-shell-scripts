#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SRC='/data/www/traindata/imgs/'
DES='/data/www/traindata/imgs/'
IPARRAY=(
    10.32.84.93:8888
    10.98.240.19:8888
    10.32.72.159:8888
    10.32.33.133:8888
    10.32.84.64:8888
    10.32.72.97:8888
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
