#!/bin/bash
# e.g.
export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:~/bin

IP_INTERFACE=$(ip addr list | grep -E '192.168.0|172.16.60' | awk '{print $NF}')
echo "关注第5、6列，单位为 kb/s"
echo "Collect network interface："
for item in $(seq 1 60);do
    echo $(date)
    sar -n DEV 1 60 | grep "${IP_INTERFACE}"
done
