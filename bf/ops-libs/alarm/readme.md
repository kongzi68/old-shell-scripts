## 使用帮助说明

```bash
IamUsername@username:~/test/script_libs# python3 ops_alarm.py -h
usage: ops_alarm.py [-h] [-u] [-v] {email,sms} ...

Send sms or Email.
____________________________
Help:
    python ops_alarm.py email -h
    python ops_alarm.py sms --help
Usage Examples:
    python ops_alarm.py email zhangsan,lisi
    python ops_alarm.py email zhangsan,lisi -cc wangmazi
    python ops_alarm.py email -r colin -s 'this is test' < email.txt

optional arguments:
  -h, --help     show this help message and exit
  -u, --update   从api获取最新的姓名、电话、邮件地址等
  -v, --version  显示版本信息

功能模块:
  发送邮件，或发送短信

  {email,sms}
    email        发送邮件
    sms          发送短信
IamUsername@username:~/test/script_libs# python3 ops_alarm.py email -h
usage: ops_alarm.py email [-h] -r RECEIVERS [-cc CC_RECEIVERS] -s SUBJECT [-c CONTENT] [-a ANNEXS]

optional arguments:
  -h, --help            show this help message and exit

发送邮件:
  -r RECEIVERS, --receivers RECEIVERS
                        接收者的姓名或姓名拼音全拼，用逗号分隔，只有一个时末尾不用加逗号
  -cc CC_RECEIVERS, --cc_receivers CC_RECEIVERS
                        抄送者的姓名或姓名拼音全拼，用逗号分隔，只有一个时末尾不用加逗号
  -s SUBJECT, --subject SUBJECT
                        邮件的主题，收到邮件时显示的标题
  -c CONTENT, --content CONTENT
                        邮件内容
  -a ANNEXS, --annexs ANNEXS
                        邮件附件，附件名称与名称之间用逗号隔开，只有一个名称时末尾不用加逗号
```

## alarm工具使用参考

```bash
python3 ops_alarm.py email -r colin -s 'this is test' < email.txt

# 发送邮件
[IamUsername@hxsz-reptile-test scripts]# sh -x test.sh 
++ date '+%F %T:%N'
+ python3 ./ops_alarm.py email -r colin -s OFFICE数据采集，postgresql主从故障 -c '2020-06-19 17:09:18:922472222，OFFICE：内网数据采集服务器，postgresql主从同步-故障'
2020-06-19 17:09:19,186 INFO ops_alarm-294::{'update': False, 'receivers': 'colin', 'cc_receivers': None, 'subject': 'OFFICE数据采集，postgresql主从故障', 'content': '2020-06-19 17:09:18:922472222，OFFICE：内网数据采集服务器，postgresql主从同步-故障', 'annexs': None}
2020-06-19 17:09:19,186 INFO ops_alarm-315::发送邮件
2020-06-19 17:09:29,436 INFO ops_alarm-136::kongzi68@dingtalk.com
2020-06-19 17:09:29,791 INFO ops_alarm-138::发送邮件给 kongzi68@dingtalk.com 成功.
[IamUsername@hxsz-reptile-test scripts]# ls
clean_pg_archivedir_log.sh  ops_alarm.py  test.sh
[IamUsername@hxsz-reptile-test scripts]# cat test.sh 
#!/bin/bash

python3 ./ops_alarm.py email -r colin -s "OFFICE数据采集，postgresql主从故障" -c "$(date +%F" "%T":"%N)，OFFICE：内网数据采集服务器，postgresql主从同步-故障"
```