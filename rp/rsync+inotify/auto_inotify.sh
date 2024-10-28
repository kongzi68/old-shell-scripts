#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SRC='/data/www/traindata/imgs/'
TARGET_MODULE='hls'
RSYNC_PAS='/etc/rsync.pas'
IPARRAY=(
    iamIPaddress
    iamIPaddress
    iamIPaddress
    iamIPaddress
    iamIPaddress
)

inotifywait -mrq --timefmt '%d/%m/%y-%H:%M' --format '%T %w%f' -e modify,delete,create,attrib ${SRC} | while read file
do
    for IP in ${IPARRAY[@]}
    do
        rsync -avzP --delete ${SRC}  upload@${IP}::${TARGET_MODULE}  --password-file=${RSYNC_PAS} >> /dev/null 2>&1
    done
done

