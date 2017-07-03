#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SRC='/data/www/traindata/imgs/'
DES='/data/www/traindata/imgs/'
IPARRAY=(
    9.0.0.90
    9.0.8.90
    9.0.16.90
    9.0.56.90
    9.0.72.90
)

inotifywait -mrq --timefmt '%d/%m/%y-%H:%M' --format '%T %w%f' -e modify,delete,create,attrib ${SRC} | while read file
do
    for IP in ${IPARRAY[@]}
    do
        rsync -avzP "-e ssh -p 22" --delete ${SRC}  root@${IP}:${DES} >> /dev/null 2>&1
    done
done
