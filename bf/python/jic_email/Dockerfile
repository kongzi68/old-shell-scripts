FROM python:3.11.3-bullseye
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
RUN pip install --no-cache-dir --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple oracledb

WORKDIR /opt/iamUserName/
RUN apt-get install -y vim && \
    mkdir -p /opt/iamUserName/conf
COPY jicSendEmailOrSMS.py /opt/iamUserName/
COPY README.md /opt/iamUserName/
