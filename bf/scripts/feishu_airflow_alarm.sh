#!/bin/bash
## airflow告警消息发送到飞书
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
                                "text": "消息内容: '${MSG}'\n"
                            },
                            {
                                "tag": "at",
                                "user_id": "iamsecret",
                                "user_name": "张三"
                            },
                            {
                                "tag": "at",
                                "user_id": "ou_6c5fb73cbaed553b14f5769fa099fb85",
                                "user_name": "晏奇"
                            }
                        ]]
                    }
                }
            }
        }' \
    https://open.feishu.cn/open-apis/bot/v2/hook/iamsecret
    echo -e '\n'
}

sendMsgByFeishu "airflow数据更新告警通知" "啊啊啊啊啊啊啊啊啊啊啊啊啊啊啊啊啊"
