#!/bin/bash
# Tag_ETF_all_zx全部行业数据更新，通知发起状态监控

cd /data2t/iamUserName/saas-data/log
NOW_DATE="$(date '+%Y-%m-%d')"
NOTIFY_DATE="""$(grep -iE "$1" saas-data-etl-${NOW_DATE}*.log saas-data-etl.log | grep -i "Tag_ETF_all_zx" | grep "success notify" | awk -F'|' '{print $2}' | awk '{print $1}')"""
if [ "${NOTIFY_DATE}" = "${NOW_DATE}" ];then
    STATUS_TAG_ETF_ALL_ZX=true
else
    STATUS_TAG_ETF_ALL_ZX=false
fi
echo "data,type=check,region=shanghai,customer=$2,name=saasdata-single-tag-etf-all-zx tag_etf_all_zx_notify_status=${STATUS_TAG_ETF_ALL_ZX}"
