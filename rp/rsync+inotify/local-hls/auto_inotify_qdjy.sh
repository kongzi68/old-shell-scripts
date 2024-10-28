#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SRC='/data/www/traindata/imgs/'
DES='/data/www/traindata/imgs/'
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
        rsync -avzP "-e ssh -p 22" --delete ${SRC}  IamUsername@${IP}:${DES} >> /dev/null 2>&1
    done
done
