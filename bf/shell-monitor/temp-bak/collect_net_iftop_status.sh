#!/bin/bash
# e.g.
export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:~/bin

IP_INTERFACE=$(ip addr list | grep -E '192.168.0|172.16.60' | awk '{print $NF}')
echo $(date)
iftop -i ${IP_INTERFACE} -n -P -t -s 60
