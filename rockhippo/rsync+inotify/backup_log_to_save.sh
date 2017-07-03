#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
SRC='/data/logs/'

inotifywait -mrq --timefmt '%d/%m/%y-%H:%M' --format '%T %w%f' -e modify,delete,create,attrib ${SRC} | while read file
do
    rsync -avzP -m -f"+ */" -f"+ *.tar.gz" -f"+ wificonnect*.log" -f"- *" ${SRC}  /logs/old_log/ >> /dev/null 2>&1
done
