## 复制下面的脚本内容到 n9e 中
#+ 注意，需要使用 n9e 自建的脚本头
IP_INTERFACE=$(ip addr list | grep -E '192.168.0|172.16.60' | awk '{print $NF}')
echo "Collect network interface："
sar -n DEV 1 5 | grep "${IP_INTERFACE}"
echo "关注第5、6列，单位为 kb/s"

DATA_NOW=$(date +%Y%m%d%H%M%S)
TCPDUMP_FILE="/tmp/devops-tcpdump-${DATA_NOW}.cap"
tcpdump -nn -i "${IP_INTERFACE}" -c 200 -w "${TCPDUMP_FILE}"
[ -f "${TCPDUMP_FILE}" ] && echo "Tcpdump to file ${TCPDUMP_FILE} done."

NETSTAT_FILE="/tmp/devops-netstat-${DATA_NOW}.txt"
netstat -ntlap > "${NETSTAT_FILE}"
[ -f "${NETSTAT_FILE}" ] && echo "Netstat to file ${NETSTAT_FILE}."