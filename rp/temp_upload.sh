#!/bin/bash
cd_dir=$1    #输入需要上传到的文件夹
lcd_dir=$2    #修改日志所在的文件夹
LASTTIME=$4

[ -z "$*" -o "$#" -ne 4 ] && {
    echo 
    echo -e "\033[31mPlease Usage: sh `basename $0` /nginxlog/sd/jn /data/store/logs/backup nginxlog 201511031800\033[0m"
    echo
    exit
}

ftp_err_dir="/tmp/ftp_err/"
[ -d ${ftp_err_dir} ] || mkdir -p ${ftp_err_dir}
ftp_err_log="${ftp_err_dir}ftp_temp_${log_type}_err.log"
send_log(){
    ftp -ivn iamIPaddress 21 2>${ftp_err_log} << _EOF_
    user upload chriscao
    passive
    bin
    lcd ${lcd_dir}
    cd  ${cd_dir}
    put $1
    bye
_EOF_
#统计前面FTP运行输出的错误日志记录行数
log_count=`cat ${ftp_err_log}|wc -l`
[ ${log_count} -eq 0 ] &&  return 0 || return 1
}
cd ${lcd_dir} && {
    #每次重新上传的时候，记得修改这里创建的tmp_file.txt的时间
    tmp_file=`touch -t "$4" tmp_file.txt`
    file_list=`find -newer tmp_file.txt -print|grep "$3"`
    for i in ${file_list}
    do
        tmp_i=`echo $i |sed "s#./##g"`
        [ -f ${tmp_i} ] && {
            send_log "${tmp_i}"
            [ $? -eq 0 ] && echo "Put the ${tmp_i} done..." || echo "Please put the ${tmp_i} again."
        } || echo "It's not a file, Pass..."
    done
    rm tmp_file.txt
}
cd ${ftp_err_dir} && [ -f ${ftp_err_log} ] && rm ${ftp_err_log}

