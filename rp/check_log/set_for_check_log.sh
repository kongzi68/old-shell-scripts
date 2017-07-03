#! /bin/sh
#auto set the system environment for the check_log.sh
#by colin on 2015-06-25

echo "\033[32mNow, To set the system environment for the check_log.sh\033[0m"
#install command mailx and dos2unix
apt-get -y install heirloom-mailx dos2unix
#set /etc/nail.rc, use command mailx to send mail
sed -i "/sendcharsets/s/=.*/=GB2312/g" /etc/nail.rc
cat >> /etc/nail.rc <<EOF
set from=kongzi68@126.com  smtp=smtp.126.com
set smtp-auth-user=kongzi68  smtp-auth-password=ivxrlegagvlmnvrs
set smtp-auth=login
EOF

scripts='/root/check_log/check_log.sh'
if [ -f ${scripts} ];then
    chmod +x ${scripts};
    echo "* * * * * /bin/sh ${scripts} >>/var/log/check_log_run_stats.log" >>/var/spool/cron/crontabs/root
else
    echo "\033[31mPlease check if there is the check_log.sh in the root directory.\033[0m"
fi
echo "\033[32mDone.\033[0m"
