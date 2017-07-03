#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SRC='/data/www/traindata/imgs/'
TARGET_MODULE='hls'
RSYNC_PAS='/etc/rsync.pas'
IPARRAY=(
    222.32.65.10
    221.0.187.10
    61.232.45.10
    221.173.128.10
    118.244.237.10
)

inotifywait -mrq --timefmt '%d/%m/%y-%H:%M' --format '%T %w%f' -e modify,delete,create,attrib ${SRC} | while read file
do
    for IP in ${IPARRAY[@]}
    do
        rsync -avzP --delete ${SRC}  upload@${IP}::${TARGET_MODULE}  --password-file=${RSYNC_PAS} >> /dev/null 2>&1
    done
done

