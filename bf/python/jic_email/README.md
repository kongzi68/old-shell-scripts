## 重要说明

在 `/opt/iamUserName` 下：
1. `README.md` 为帮助说明文档
2. `jicSendEmailOrSMS.py` 是工具脚本
3. `conf` 是挂载的配置文件目录

```shell
docker run -it --rm --name jicSendEmailOrSMS \
  -v /data/iamUserName/jicSendEmailOrSMS/conf:/opt/iamUserName/conf \
  -w /opt/iamUserName \
  harbor.betack.com/jic/jictrust-send-email-or-sms:20230506-v1 \
  ls -lh /opt/iamUserName

IamUsername@python-dev:/data/jic_email# docker run -it --rm --name jicSendEmailOrSMS -v /data/iamUserName/jicSendEmailOrSMS/conf:/opt/iamUserName/conf -w /opt/iamUserName harbor.betack.com/jic/jictrust-send-email-or-sms:20230506-v1 ls -lh /opt/iamUserName
total 24K
-rwxr-xr-x 1 IamUsername IamUsername 5.6K May  6 14:47 README.md
drwxr-xr-x 2 IamUsername IamUsername 4.0K May  6 14:56 conf
-rwxr-xr-x 1 IamUsername IamUsername 9.7K May  6 14:44 jicSendEmailOrSMS.py
```

## 使用方法

```shell
docker run -it --rm --name jicSendEmailOrSMS \
  -v /data/iamUserName/jicSendEmailOrSMS/conf:/opt/iamUserName/conf \
  -w /opt/iamUserName \
  harbor.betack.com/jic/jictrust-send-email-or-sms:20230506-v1 \
  python jicSendEmailOrSMS.py email -r zhangsan@betack.com -s 每日数据更新失败 -c zjt测试环境，每日数据未更新成功告警
```

## 获取脚本帮助

```shell
(jic_email-xcBVi0Dp) username@python-dev:/data/jic_email$ python jicSendEmailOrSMS.py -h
usage: jicSendEmailOrSMS.py [-h] [-v] {email,sms} ...

Send Email or SMS.
____________________________
Help:
    jicSendEmailOrSMS.py -h,--help
    jicSendEmailOrSMS.py email -h
    jicSendEmailOrSMS.py sms -h

Usage Examples:
    jicSendEmailOrSMS.py email -r 123@qq.com -s 每日数据更新失败 -c zjt测试环境，每日数据未更新成功告警
    jicSendEmailOrSMS.py email -r zhangsan@betack.com,123@qq.com -s 每日数据更新失败 -c zjt测试环境，每日数据未更新成功告警
    jicSendEmailOrSMS.py sms -r 15982363559 -m zjt测试环境，每日数据未更新成功告警
    jicSendEmailOrSMS.py sms -r 15982363559,16789001111 -m zjt测试环境，每日数据未更新成功告警

optional arguments:
  -h, --help     show this help message and exit
  -v, --version  显示版本信息

功能模块:
  {email,sms}
    email        zjt邮件通知
    sms          zjt短信通知
```

### 获取发送短信帮助

```shell
(jic_email-xcBVi0Dp) username@python-dev:/data/jic_email$ python jicSendEmailOrSMS.py sms -h
usage: jicSendEmailOrSMS.py sms [-h] -r RECEIVERS [-t TITLE] -m MESSAGE

发送短信告警
----------------------------------------
Usage:
   jicSendEmailOrSMS.py sms -h,--help
   jicSendEmailOrSMS.py sms -r 15982360120 -m zjt测试环境，每日数据未更新成功告警
   jicSendEmailOrSMS.py sms -r 15982360120,16782560199 -t 每日数据更新失败 -m zjt测试环境，每日数据未更新成功告警

optional arguments:
  -h, --help            show this help message and exit

短信通知:
  -r RECEIVERS, --receivers RECEIVERS
                        接收者的手机号码，多个接收者用逗号分隔
  -t TITLE, --title TITLE
                        告警短信标题，默认值：短信告警
  -m MESSAGE, --message MESSAGE
                        告警短信内容
```

### 获取发邮件帮助 

```shell
(jic_email-xcBVi0Dp) username@python-dev:/data/jic_email$ python jicSendEmailOrSMS.py email -h
usage: jicSendEmailOrSMS.py email [-h] -r RECEIVERS [-s SUBJECT] -c CONTENT

发送邮件告警
----------------------------------------
Usage:
   jicSendEmailOrSMS.py email -h,--help
   jicSendEmailOrSMS.py email -r zhangsan@qq.com -c zjt测试环境，每日数据未更新成功告警
   jicSendEmailOrSMS.py email -r zhangsan@qq.com,lisi@163.com -s 每日数据更新失败 -c zjt测试环境，每日数据未更新成功告警

optional arguments:
  -h, --help            show this help message and exit

邮件通知:
  -r RECEIVERS, --receivers RECEIVERS
                        接收者的邮件地址，多个接收者用逗号分隔
  -s SUBJECT, --subject SUBJECT
                        告警邮件主题，收到邮件时显示的标题，默认值：邮件告警
  -c CONTENT, --content CONTENT
                        告警邮件内容
```

## 开发环境准备

```shell
IamUsername@python-dev:/data/jic_email# cat Dockerfile_python
FROM python:3.9.16-bullseye
LABEL maintainer="colin" version="1.0" datetime="2023-05-06"
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apt install apt-transport-https ca-certificates && \
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
COPY sources.list /etc/apt/sources.list
ADD instantclient_11_2 /opt/tools/instantclient_11_2
RUN apt-get update && apt-get install -y libaio1 && \
    echo '/opt/tools/instantclient_11_2' > /etc/ld.so.conf.d/oracle-instantclient.conf && \
    ln -s /opt/tools/instantclient_11_2/libclntsh.so.11.1 /opt/tools/instantclient_11_2/libclntsh.so && \
    ldconfig
RUN pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip install -i https://pypi.tuna.tsinghua.edu.cn/simple oracledb

IamUsername@python-dev:/data/jic_email# cat sources.list
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free

# deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free
# # deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free

deb https://security.debian.org/debian-security bullseye-security main contrib non-free
# deb-src https://security.debian.org/debian-security bullseye-security main contrib non-free


docker image build -t iamIPaddress/jic/jictrust-send-email-or-sms:python-tool -f Dockerfile_python .
```
