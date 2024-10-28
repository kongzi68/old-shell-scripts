#!/bin/bash
# e.g.
export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:~/bin
echo $(date)
for item in $(seq 1 12);do
    sleep 5 
    echo "-----------------------------------------"
    netstat -ntlap 
    echo "-----------------------------------------"
done
