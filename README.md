[TOC]
***
# 说明
包含以前写的shell与python脚本。清理了重要的密码、用户名，以及真实的IP地址。
## 脚本用途简要说明
```
root@ubuntu:/data/shell_scripts# tree 
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
│   ├── cut_and_upload            # 重点推荐，用于向FTP服务器上传日志文件，失败后重传、补传
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
│   ├── installSourceCode
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
│   ├── rsync+inotify
│   │   ├── auto_inotify.sh
│   │   ├── backup_log_to_save.sh
│   │   ├── local-hls
│   │   │   ├── auto_inotify_jn.sh
│   │   │   ├── auto_inotify_qdjy.sh
│   │   │   ├── auto_inotify_qdn.sh
│   │   │   ├── auto_inotify_qqhr.sh
│   │   │   └── scripts_run_status_check.sh
│   │   └── scripts_run_status_check.sh
│   ├── system_status.sh
│   ├── temp_upload.sh
│   ├── toPIng
│   │   ├── ip.txt
│   │   └── toPing.sh
│   └── web_jn_dns_switch_qdn.sh
└── wp
    ├── python
    │   ├── allgs_count
    │   │   ├── get_allgs_login_and_charge.py
    │   │   ├── get_allgs_login_and_task_statistics.py
    │   │   ├── get_allgs_vip_charge_cost.py
    │   │   └── get_allgs_vip_distribution.py
    │   ├── dolist.db
    │   ├── get_charge_and_item_cost.py
    │   ├── get_charge_list.py
    │   ├── getGMSInfo
    │   │   ├── getGameServerList.py
    │   │   └── gslist.db
    │   ├── get_player_level_distribution.py
    │   ├── get_server_config_xml.py
    │   ├── parse_pb_demo_change.py
    │   ├── player_login_query
    │   │   ├── get_player_task_and_login.py
    │   │   ├── query_DB_VIPAssetData_PB_and_player_login_info.py
    │   │   ├── query_new_gsserver.py
    │   │   └── query_player_login_info_by_chartype.py
    │   ├── query_charge_top50.py
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
    │   ├── query_player_gold_list_new_change.py
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
    │   ├── salt_modules
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
        ├── bak_mysql.sh
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
        ├── mysql_install.sh
        ├── open.sh
        ├── scripts_run_status_check.sh
        └── send_log.sh

22 directories, 143 files
```