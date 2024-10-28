#!/bin/bash

## 飞书机器人消息通知
#+ MSG 不能包含空格
#+ 变量必须要用单引号包裹
sendMsgByFeishu() {
    MSG_TITLE=$1
    MSG=$2
    curl -X POST -H "Content-Type: application/json" \
    -d '{
            "msg_type": "post",
            "content": {
                "post": {
                    "zh_cn": {
                        "title": "'${MSG_TITLE}'",
                        "content": [[
                            {
                                "tag": "text",
                                "text": "命名空间: '${MY_POD_NAMESPACE}'\n"
                            },
                            {
                                "tag": "text",
                                "text": "消息内容: '${MSG}'\n"
                            },
                            {
                                "tag": "at",
                                "user_id": "iamsecret",
                                "user_name": "张三"
                            }
                        ]]
                    }
                }
            }
        }' \
    https://open.feishu.cn/open-apis/bot/v2/hook/iamsecret
    echo -e '\n'
}