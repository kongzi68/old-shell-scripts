#!/bin/bash
#+ 检查 jfrog 是否运行
#+ 检查容器名为：artifactory的容器是否处于running状态

CONTAINER_ID=$(docker ps -q -a --filter name=artifactory --filter status=running)
#+ 容器ID不为空，表示容器正在运行
if [ -n "${CONTAINER_ID}" ];then
    IS_RUNNING=1
else
    IS_RUNNING=0
fi

echo "jfrog,type=tools,region=hwcloud,name=jfrog_artifactory container_up=${IS_RUNNING}"