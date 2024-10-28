#!/bin/bash
# 用于导出少四的充值数据，并发送给财务等
# 通过ssh免密匙的方式,密匙文件/IamUsername/.ssh/shaosi_charge，shaosi_charge.pub

lastmonth=$(date -d last-month +%Y-%m)
passwd='thisispassword'

EMAIL=(
    zhangsan@windplay.cn
    test1@windplay.cn
)

# 导出IOS充值
ssh -i /IamUsername/.ssh/shaosi_charge db02@iamIPaddress mysql -udb02 -h'iamIPaddress' -p"${passwd}" -P3306 > IOSFinish${lastmonth}.txt <<-EOF
    use Charge_zb;
    select transaction_id,totalmoney,time from IOSFinish where (time>='${lastmonth}-01 00:00:00' and time<='${lastmonth}-31 23:59:59');
EOF
# 导出第三方充值
ssh -i /IamUsername/.ssh/shaosi_charge db02@iamIPaddress mysql -udb02 -h'iamIPaddress' -p"${passwd}" -P3306 > ThirdFinish${lastmonth}.txt <<-EOF
    use Charge;
    select thirdorderid,totalmoney,time from ThirdFinish where (time>='${lastmonth}-01 00:00:00' and time<='${lastmonth}-31 23:59:59');
EOF

sendEmail(){
    for emailaddr in ${EMAIL[@]};do
        echo "Shaosi ${lastmonth} Recharge Record" | mail -s "Shaosi ${lastmonth} Recharge Record" -a IOSFinish${lastmonth}.txt -a ThirdFinish${lastmonth}.txt ${emailaddr}
        [ $? -eq 0 ] && echo "$(date +%F" "%T":"%N) Send email to ${emailaddr}."
    done
    return 0
} 

sendEmail
rm IOSFinish${lastmonth}.txt ThirdFinish${lastmonth}.txt -f