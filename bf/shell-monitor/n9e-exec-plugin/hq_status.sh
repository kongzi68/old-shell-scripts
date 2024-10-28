#!/bin/bash
# hq.betack.com数据更新监控上报

HQ_TIME_STAMP="$(curl -s http://iamIPaddress:32524/stock/time/1701049577000/1701049577000 | jq -r '.stockMarketList[] | select(.stockCode=="000001") | .time')"
echo """hq,region=shanghai,name=exec_hq_iamUserName_com update_time=$(date -d "${HQ_TIME_STAMP}" +%s)"""