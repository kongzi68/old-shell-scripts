#!/bin/bash
#auto backup and recovery DIR by tar command
#by colink on 2015-05-10
#备份指定的文件夹

TAR_SNAPSHOT_FILES='/tmp/tar_snapshot_files'
TAR_BACKUP_DIR="/data/backup/`date +%Y%m%d`" #存放备份的文件夹
TO_BACKUP_DIRNAME=( $* )  #需要备份的文件夹
DATE_YMD=`date +%Y%m%d`
DATE_WEEK=`date +%w`

#为备份的准确性，一定要保证时间准确
#ntpdate pool.ntp.org

#备份状态检测
function backup_dir_status() {
if [ $? = 0 ];then
    echo -e "\033[32m--------------------------------------------------\033[0m"
    echo -e "\033[32mBackup DIR ${i} to ${TAR_BACKUP_DIR}_${DATE_WEEK}/${BACKUP_DIRNAME}_full_${DATE_YMD}_${DATE_WEEK}.tar.gz was successfully...\033[0m"
else
    echo -e "\033[31m--------------------------------------------------\033[0m"
    echo -e "\033[31mBackup DIR ${i} was failed,Please check...\033[0m"
fi
}
#备份文件夹函数；每周一次全备，其余增量备份，一周一个循环共7次。
#DATE_WEEK=0时，是星期天，这天执行全备
function backup_dir() {
if [ "${DATE_WEEK}" -eq 0 ];then
	#循环备份所有指定的文件夹
	for i in ${TO_BACKUP_DIRNAME[@]}
	do
		BACKUP_DIRNAME=`echo "${i}" |sed 's/\// /g' |awk '{print $NF}'`  #备份文件夹主名
		tar -g ${TAR_SNAPSHOT_FILES} -czf ${TAR_BACKUP_DIR}_${DATE_WEEK}/${BACKUP_DIRNAME}_full_${DATE_YMD}_${DATE_WEEK}.tar.gz ${i}
		backup_dir_status;
	done
else
	for i in ${TO_BACKUP_DIRNAME[@]}
	do
		BACKUP_DIRNAME=`echo "${i}" |sed 's/\// /g' |awk '{print $NF}'`  #备份文件夹主名
		tar -g ${TAR_SNAPSHOT_FILES} -czf ${TAR_BACKUP_DIR}_${DATE_WEEK}/${BACKUP_DIRNAME}_add_${DATE_YMD}_${DATE_WEEK}.tar.gz ${i}
		backup_dir_status;
	done
fi
}
#备份文件夹检测，若创建成功，就开始备份
function mk_dir(){
if [ ! -d ${TAR_BACKUP_DIR}_${DATE_WEEK} ];then
    echo -e "\033[31mThe backup DIR is't exist,Will create...\033[0m"
    mkdir -p ${TAR_BACKUP_DIR}_${DATE_WEEK}
    if [ $? = 0 ];then
        echo -e "\033[32mThe backup DIR was created successfully...\n+++++++++++++++下面将开始进行文件夹备份+++++++++++++++\033[0m"
        backup_dir;
    else
        echo -e "\033[31mThe backup DIR was created failed,Please check...\033[0m"
        exit
    fi
else
    echo -e "\033[31mThe backup DIR is exist,Please don't backup again!\033[0m"
fi
}
#使用帮助及参数合法性判断
if [ $# -eq 0 ];then
    echo -e "\033[32mUsage command:sh $0 /boot /IamUsername \033[0m"
else
    #判断输入的文件夹是否存在
    for i in ${TO_BACKUP_DIRNAME[@]}
    do
        if [ ! -d ${i} ];then
            echo -e "\033[31mThe dir ${i} is't exist,Please input again... \033[0m"
            exit
        fi
    done
	#若输入的参数合法，在循环完成之后，就调用函数mk_dir
	mk_dir;
fi
