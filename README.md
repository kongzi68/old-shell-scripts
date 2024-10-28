[TOC]

***

# 说明

包含以前写的shell与python脚本。清理了重要的密码、用户名，以及真实的IP地址。

## 2022-2024年，shell、python脚本

```bash
$ tree
.
├── README.md
├── ansible.cfg
├── ansible_hosts
├── ops-libs
│   ├── README.md
│   ├── alarm
│   │   ├── ops_alarm.py
│   │   └── readme.md
│   └── script-libs              # 公共脚本函数库
│       └── functions.sh
├── python
│   ├── jic_email                 # 某**内部告警消息提交，python脚本
│   │   ├── Dockerfile
│   │   ├── Dockerfile_bak
│   │   ├── Dockerfile_python
│   │   ├── README.md
│   │   ├── instantclient_11_2
│   │   │   ├── BASIC_README
│   │   │   ├── adrci
│   │   │   ├── genezi
│   │   │   ├── libclntsh.so.11.1
│   │   │   ├── libnnz11.so
│   │   │   ├── libocci.so.11.1
│   │   │   ├── libociei.so
│   │   │   ├── libocijdbc11.so
│   │   │   ├── ojdbc5.jar
│   │   │   ├── ojdbc6.jar
│   │   │   ├── uidrvci
│   │   │   └── xstreams.jar
│   │   ├── jicSendEmailOrSMS.py
│   │   └── sources.list
│   └── 数据库导入导出
│       ├── Dockerfile
│       ├── export-tools-create-table.py
│       └── export_sql_to_csv.py
├── scripts
│   ├── feishu-scripts-bak20240914.sh
│   ├── feishu_airflow_alarm.sh
│   ├── increment_rsync_parquet.sh
│   ├── temp
│   └── update_mosek_lic.sh
├── shell-monitor
│   ├── README.md
│   ├── jictrust                                 # 某**内网服务器基础监控告警脚本
│   │   ├── bak_mysql_db.sh
│   │   ├── collect_container_status.sh
│   │   ├── collect_disk_utilization_status.sh
│   │   ├── collect_svc_port_status.sh
│   │   ├── collect_system_load_status.sh
│   │   ├── libs
│   │   │   └── functions.sh
│   │   └── restart_svc_container.sh
│   ├── n9e-exec-plugin
│   │   ├── collect_exec_check_process.sh
│   │   ├── collect_exec_tag_etf_all_zx.sh
│   │   ├── hq_status.sh
│   │   └── jfrog
│   │       ├── collect_jfrog_container_status.sh
│   │       └── jfrog_container_start.sh
│   ├── n9e-scripts
│   │   └── devops_deploy_shell_scripts.sh
│   └── temp-bak
│       ├── collect_net_iftop_status.sh
│       ├── collect_net_nethogs_status.sh
│       ├── collect_net_netstat_status.sh
│       ├── collect_net_recv_sent_status-bak.sh
│       └── collect_net_recv_sent_status.sh
└── shell-scripts
    ├── 122-112-142-69-check_wind.sh
    ├── 192-168-0-104-auto_start_jenkins.sh
    ├── 192-168-0-104-ping_check.sh
    ├── api3_error_log_check_sql_connection.sh
    ├── api3_restart_svc_docker.sh
    ├── api4_restart_svc_docker.sh
    ├── bak_files_to_minio.sh
    ├── bak_files_to_minio_1.sh
    ├── bak_mysql_db.sh
    ├── bak_mysql_db_no_create_databases.sh
    ├── bak_mysql_db_to_minio.sh
    ├── bak_mysql_db_to_minio_1.sh
    ├── bak_mysql_db_to_minio_2.sh
    ├── by_reg_delete_old_file.sh
    ├── deploy-n9e-client-office.sh
    ├── deploy-n9e-client.sh
    └── mod_telegraf_hwcloud_api3_ip.sh

17 directories, 68 files
```

## 2018-05以前：脚本用途简要说明

备注过的属于重点推荐脚本，其它未备注的也有很多自认为写得还是比较好的。
这些脚本，算是慢慢成长的见证吧

```bash
IamUsername@ubuntu:/data/shell_scripts# tree 
.
├── qf
│   ├── auto_backup_tar.sh
│   ├── auto_disk_monitoring_alarm.sh
│   ├── auto_service_status_email_alarm.sh
│   ├── auto_ssh_exec_command.sh
│   ├── get_mysql_status.sh
│   ├── install_lamp20150502.sh
│   ├── iptables.sh
│   ├── mod_ip_hostname.sh
│   ├── mod_ip_hostname_v2.sh
│   ├── mod_xshell_session_config.sh
│   ├── mysql_master_slave.sh
│   ├── yum_lamp_mysql_ms.sh
│   └── 按键精灵
│       └── 防暂停脚本与附件图片
│           ├── app_down.bmp
│           ├── close_app_down.bmp
│           ├── continue.bmp
│           ├── continue_next.bmp
│           ├── continue_next_start.bmp
│           ├── start.bmp
│           ├── 随机移动鼠标光标_20176161529.Q
│           └── 随机移动鼠标光标_2017616182.Q
├── README.md
├── rp
│   ├── check_ap_status.sh
│   ├── check_log           # 用于检查FTP服务器上存储的日志文件是否都被正确上传
│   │   ├── check_log.sh
│   │   └── set_for_check_log.sh
│   ├── checkPhpfpm.sh
│   ├── checkPingResult.sh
│   ├── check_system_status_v3.sh
│   ├── checkVPN
│   │   └── checkVPN.py
│   ├── create_user_and_set_sudoer.sh
│   ├── creat_tongji_hoobanr_com.sh
│   ├── cut_and_upload            # 用于向FTP服务器上传日志文件，失败后重传、补传
│   │   ├── aclog_backup_and_upload.sh
│   │   ├── authlog_wificonnect_upload.sh
│   │   ├── cut_log_everyday_array.sh
│   │   ├── gateway_backup_and_upload.sh
│   │   ├── jiaoyun_authlog_cut.sh
│   │   ├── mysql_backup_local.sh
│   │   ├── mysql_backup.sh
│   │   ├── nginxlog_cut_and_upload.sh
│   │   ├── upload_aclog.sh
│   │   ├── upload_gatewaylog.sh
│   │   ├── upload_record_gonet.sh
│   │   └── upload_tongji_record.sh
│   ├── docker
│   │   └── dockerfile
│   │       ├── apache
│   │       └── ssh
│   ├── download_log_to_chengdu.sh
│   ├── download_log_to_chengdu_v2.sh
│   ├── get_system_info.sh
│   ├── importData.sh
│   ├── installSourceCode             # 适用于ubuntu系统，源码安装mysql、nginx、php、DNS等
│   │   ├── centos_nginx
│   │   ├── centos_php-fpm
│   │   ├── installBySourceCode.sh
│   │   ├── start_centos_nginx.sh
│   │   ├── start_php-fpm
│   │   └── start_ubuntu_nginx
│   ├── jybus-scripts
│   │   └── run_scripts.sh
│   ├── mod_aclog_and_gatewaylog_scripts.sh
│   ├── mod_bind9_dns.sh
│   ├── mod_hostname.sh
│   ├── mod_m3u8.sh
│   ├── mod_shell_scripts.sh
│   ├── README.md
│   ├── rsync+inotify                 # 用于自动更新代码与静态资源的脚本，需配合rsync使用
│   │   ├── auto_inotify.sh
│   │   ├── backup_log_to_save.sh
│   │   ├── local-hls
│   │   │   ├── auto_inotify_jn.sh
│   │   │   ├── auto_inotify_qdjy.sh
│   │   │   ├── auto_inotify_qdn.sh
│   │   │   ├── auto_inotify_qqhr.sh
│   │   │   └── scripts_run_status_check.sh
│   │   └── scripts_run_status_check.sh
│   ├── system_status.sh               # 定时采集ubuntu服务器的系统状态数据，发送到API接口
│   ├── temp_upload.sh
│   ├── toPIng
│   │   ├── ip.txt
│   │   └── toPing.sh
│   └── web_jn_dns_switch_qdn.sh
└── wp
    ├── python
    │   ├── allgs_count                # 全服统计分析汇总某些数据
    │   │   ├── get_allgs_login_and_charge.py
    │   │   ├── get_allgs_login_and_task_statistics.py
    │   │   ├── get_allgs_vip_charge_cost.py
    │   │   └── get_allgs_vip_distribution.py
    │   ├── dolist.db
    │   ├── get_charge_and_item_cost.py
    │   ├── get_charge_list.py
    │   ├── getGMSInfo                 # python、saltstack，采集游戏服配置文件
    │   │   ├── getGameServerList.py
    │   │   └── gslist.db
    │   ├── get_player_level_distribution.py
    │   ├── get_server_config_xml.py
    │   ├── parse_pb_demo_change.py
    │   ├── player_login_query                # 统计游戏数据
    │   │   ├── get_player_task_and_login.py
    │   │   ├── query_DB_VIPAssetData_PB_and_player_login_info.py
    │   │   ├── query_new_gsserver.py
    │   │   └── query_player_login_info_by_chartype.py
    │   ├── query_charge_top50.py             # 统计充值与VIP数据
    │   ├── query_charge_username_and_charname.py
    │   ├── query_DB_ActorInnAsset_PB.py
    │   ├── query_DB_AllianceAsset_PB.py
    │   ├── query_DB_AllianceNewResource_PB.py
    │   ├── query_db_mountentry_pb.py
    │   ├── query_nkore_cid.py
    │   ├── query_oss_record_additem_cn.py
    │   ├── query_oss_record_additem.py
    │   ├── query_player_charname.py
    │   ├── query_player_gold_info_list.py
    │   ├── query_player_gold_list_new_change.py        # 全服拉取符合要求的玩家宝石数据，并执行清理操作
    │   ├── query_player_gold_list_new.py
    │   ├── query_player_gold.py
    │   ├── query_player_info.py
    │   ├── query_player_info_tmp_ciduid.py
    │   ├── query_player_info_tmp_siduidcid.py
    │   ├── query_player_info_up.py
    │   ├── query_table_t_char_soloteam.py
    │   ├── query_table_t_char_soloteam_up.py
    │   ├── query_vip_all_nk.py
    │   ├── query_vip_all.py
    │   ├── rank
    │   │   ├── clear_auction
    │   │   ├── clear_defstate
    │   │   ├── order_all.py
    │   │   └── read_host.py
    │   ├── salt_modules                    # python、saltstack（master、minion）更新游戏服、重启游戏服GSM等
    │   │   ├── sendMsg.py
    │   │   ├── updategs.py
    │   │   └── updatews.py
    │   ├── send_t_char_basic.py
    │   └── tmp.py
    ├── readme.txt
    └── shell
        ├── auto_reboot_ALL_RTCServer_1_5.sh
        ├── auto_reboot_oss_agent.sh
        ├── auto_start_services.sh
        ├── bak_10_104_154_151_web1.sh
        ├── bak_mysql.sh                    # 数据库备份
        ├── bak_mysql_shenji.sh
        ├── bak_oss_record_big_tables.sh
        ├── clean_useless_file.sh
        ├── clean_windows_gm_log.bat
        ├── daily_change.sh
        ├── get_chargelist_month.sh
        ├── get_chargelist_shaosi.sh
        ├── get_chargelist_week.sh
        ├── import_mysql_data.sh
        ├── lnmp1.2.tar.gz
        ├── mod_mail_address.sh
        ├── mod_thailand_time.sh
        ├── mysql_install.sh                # 通过二进制包，多实例与单实例安装与配置mysql
        ├── open.sh
        ├── scripts_run_status_check.sh
        └── send_log.sh

22 directories, 143 files
```

## 2018-05以前：PYTHON项目开发

```bash
IamUsername@ubuntu:/data/shell_scripts/wp/python# tree -L 3 .
.
├── alarm
│   ├── alarm.py
│   ├── readme
│   └── 在shell脚本中使用的示例.jpg
├── allgs_count
│   ├── get_allgs_login_and_charge.py
│   ├── get_allgs_login_and_task_statistics.py
│   ├── get_allgs_vip_charge_cost.py
│   └── get_allgs_vip_distribution.py
├── cmdb                    # CMDB数据采集
│   ├── cmdb.sh
│   ├── config
│   │   ├── cmdb.conf
│   │   └── logging.yaml
│   ├── libs
│   │   ├── db.py
│   │   ├── id.py
│   │   ├── __init__.py
│   │   ├── libemail.py
│   │   ├── log.py
│   │   └── src
│   ├── main.py
│   ├── modules
│   │   ├── __init__.py
│   │   ├── t_cdb.py
│   │   ├── t_dbserver.py
│   │   ├── t_pingfailure.py
│   │   ├── t_program.py
│   │   └── t_server.py
│   └── scripts
│       ├── get_disk.py
│       ├── get_netip.py
│       └── __init__.py
├── dolist.db
├── get_charge_and_item_cost.py
├── get_charge_list.py
├── getGMSInfo
│   ├── getGameServerList.py
│   └── gslist.db
├── get_player_level_distribution.py
├── get_server_config_xml.py
├── parse_pb_demo_change.py
├── player_login_query
│   ├── get_player_task_and_login.py
│   ├── query_DB_VIPAssetData_PB_and_player_login_info.py
│   ├── query_new_gsserver.py
│   └── query_player_login_info_by_chartype.py
├── query_charge_top50.py
├── query_charge_username_and_charname.py
├── query_DB_ActorInnAsset_PB.py
├── query_DB_AllianceAsset_PB.py
├── query_DB_AllianceNewResource_PB.py
├── query_db_mountentry_pb.py
├── query_nkore_cid.py
├── query_oss_record_additem_cn.py
├── query_oss_record_additem.py
├── query_player_charname.py
├── query_player_gold_info_list.py
├── query_player_gold_list_new_change.py
├── query_player_gold_list_new.py
├── query_player_gold.py
├── query_player_info.py
├── query_player_info_tmp_ciduid.py
├── query_player_info_tmp_siduidcid.py
├── query_player_info_up.py
├── query_table_t_char_soloteam.py
├── query_table_t_char_soloteam_up.py
├── query_vip_all_nk.py
├── query_vip_all.py
├── rank
│   ├── clear_auction
│   ├── clear_defstate
│   ├── order_all.py
│   └── read_host.py
├── ResourceMonitoring              # 低负载云服务器分析统计
│   ├── config
│   │   ├── config.conf
│   │   └── logging.yaml
│   ├── libs
│   │   ├── common.py
│   │   ├── db.py
│   │   ├── db.pyc
│   │   ├── __init__.py
│   │   ├── __init__.pyc
│   │   ├── libemail.py
│   │   ├── liblog.py
│   │   └── src
│   ├── main.py
│   ├── modules
│   │   ├── __init__.py
│   │   ├── __init__.pyc
│   │   ├── r_monitor.py
│   │   └── r_monitor.pyc
│   ├── readme
│   └── resourcemonitoring.sh
├── salt_modules                       # saltstack自定义模块
│   ├── jlmf
│   │   ├── start.py
│   │   ├── stop.py
│   │   └── updategs_jlmf.py
│   ├── sendMsg.py
│   ├── updategs.py
│   ├── updategs_t.py
│   └── updatews.py
├── send_t_char_basic.py
├── SWAMP                             # web shell脚本管理平台
│   ├── manage.py
│   ├── manage.pyc
│   ├── migrations
│   │   ├── alembic.ini
│   │   ├── env.py
│   │   ├── env.pyc
│   │   ├── README
│   │   ├── script.py.mako
│   │   └── versions
│   ├── readme.md
│   ├── requirements.txt
│   ├── settings.py
│   ├── settings.pyc
│   ├── swamp
│   │   ├── config
│   │   ├── __init__.py
│   │   ├── __init__.pyc
│   │   ├── main
│   │   ├── models.py
│   │   ├── models.pyc
│   │   ├── static
│   │   └── templates
│   └── tests
│       └── __init__.py
├── tmp.py
└── wops                             # 自动化运维平台雏形，目前含有CMDB、配置管理等的WEB平台，后续会陆续增加其他功能
    ├── config
    │   ├── config.conf
    │   ├── gunicorn.ini
    │   └── logging.yaml
    ├── config.py
    ├── db
    │   ├── cmdb_oss.sql
    │   ├── cmdb.sql
    │   └── cmdb_web.sql
    ├── manage.py
    ├── ops
    │   ├── api
    │   ├── auth
    │   ├── cfm
    │   ├── cmdb
    │   ├── __init__.py
    │   ├── libs
    │   ├── models.py
    │   ├── static
    │   └── templates
    ├── QQ图片20180301162720_看图王.png
    ├── QQ图片20180301162728_看图王.png
    ├── readme.md
    ├── requirements
    │   ├── common.txt
    │   ├── dev.txt
    │   └── prod.txt
    ├── requirements.txt
    └── tests
        └── __init__.py

40 directories, 122 files
```