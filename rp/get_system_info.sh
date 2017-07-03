#!/bin/bash
#get system info
#by colin on 2015-07-20

g_hostname=`hostname`
g_ip_eth0=`ifconfig eth0|grep Bcast |awk '{print $2}'|awk -F: '{print $2}'`
g_system_os=`cat /etc/issue|awk '{print $1$2$3}'|head -1`
t_cpu_info=`cat /proc/cpuinfo |grep "model name"|wc -l`
g_cpu_info=`cat /proc/cpuinfo |grep "model name"|head -1|awk -F: '{print $2}'|sed "s/  */ /g"`
g_user=`cat /etc/passwd |awk -F: '$3>499 {print $1}'|sed "/nobody/d"`
g_mem=`expr $(cat /proc/meminfo |grep MemTotal:|awk '{print $2}') / 1000000`

for i in ${g_user}
do
	echo "${g_system_os},${g_ip_eth0},${g_hostname},${i},${t_cpu_info}核心:${g_cpu_info},${g_mem}GB"
done

