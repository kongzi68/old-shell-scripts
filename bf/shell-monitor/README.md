

```bash
#43 * * * * cd /IamUsername/tools && bash collect_net_recv_sent_status.sh >> logs/collect_net_recv_sent_status.log 2>&1
#* * * * * cd /IamUsername/tools && bash collect_net_netstat_status.sh >> logs/collect_net_netstat_status.log 2>&1
#* * * * * cd /IamUsername/tools && bash collect_net_nethogs_status.sh >> logs/collect_net_nethogs_status.log 2>&1
#* * * * * cd /IamUsername/tools && bash collect_net_iftop_status.sh >> logs/collect_net_iftop_status.log 2>&1


```
