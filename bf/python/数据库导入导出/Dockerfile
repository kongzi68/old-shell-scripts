FROM harbor.betack.com/libs-hwcloud/python:3.9
LABEL maintainer="colin" version="1.0" datetime="2022-06-07"
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    pip install --no-cache-dir --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
WORKDIR /opt/iamUserName
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple pandas pymysql