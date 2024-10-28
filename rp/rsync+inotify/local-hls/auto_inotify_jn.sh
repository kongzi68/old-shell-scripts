#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SRC='/data/www/traindata/imgs/'
DES='/data/www/traindata/imgs/'
IPARRAY=(
    iamIPaddress:220
    iamIPaddress:8888
    iamIPaddress:8888
    iamIPaddress:8888
    iamIPaddress:8888
    iamIPaddress:8888
    iamIPaddress:8888
    iamIPaddress:8888
    iamIPaddress:8888
)

inotifywait -mrq --timefmt '%d/%m/%y-%H:%M' --format '%T %w%f' -e modify,delete,create,attrib ${SRC} | while read file
do
    for IPPORT in ${IPARRAY[@]}
    do
        IP=$(echo "${IPPORT}" | awk -F: '{print $1}')
        PORT=$(echo "${IPPORT}" | awk -F: '{print $2}')
        rsync -avzP "-e ssh -p ${PORT}" --delete ${SRC}  IamUsername@${IP}:${DES} >> /dev/null 2>&1
    done
done
