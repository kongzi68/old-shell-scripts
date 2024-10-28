#!/bin/bash
servername=${1?"Usage: sh `basename $0` HLJHEB-TS-QQHE-HLS"}
NAMEA=`hostname`
sed -i "s/${NAMEA}/${servername}/g" /etc/hosts
hostname "${servername}"
echo "${servername}" > /etc/hostname
sed -ri "/iamIPaddress/s/\s[a-z0-9]+/       ${servername}/g" /etc/hosts
[ $? -eq 0 ] && echo "=============success!================="
cat /etc/hosts
echo 
hostname
