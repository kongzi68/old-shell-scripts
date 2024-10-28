/*
Navicat MySQL Data Transfer

Source Server         : iamIPaddress
Source Server Version : 50613
Source Host           : iamIPaddress:3306
Source Database       : cmdb

Target Server Type    : MYSQL
Target Server Version : 50613
File Encoding         : 65001

Date: 2018-01-17 17:38:15
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for `t_cdb`
-- ----------------------------
DROP TABLE IF EXISTS `t_cdb`;
CREATE TABLE `t_cdb` (
  `uInstanceId` varchar(30) COLLATE utf8_bin NOT NULL COMMENT 'uInstanceId',
  `cdbInstanceName` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `cdbInstanceVip` varchar(15) COLLATE utf8_bin DEFAULT NULL,
  `cdbInstanceVport` int(5) DEFAULT NULL,
  `memory` int(10) DEFAULT NULL COMMENT '内存，单位MB',
  `volume` int(10) DEFAULT NULL COMMENT '磁盘，单位GB',
  `cdbInstanceType` int(5) DEFAULT NULL,
  `status` int(2) DEFAULT NULL,
  `engineVersion` varchar(10) COLLATE utf8_bin DEFAULT NULL,
  `price` float(8,2) DEFAULT '0.00',
  `maxQueryCount` int(6) DEFAULT NULL COMMENT '实例最大查询次数，单位：次/秒',
  PRIMARY KEY (`uInstanceId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='云数据库清单';

-- ----------------------------
-- Records of t_cdb
-- ----------------------------

-- ----------------------------
-- Table structure for `t_dbserver`
-- ----------------------------
DROP TABLE IF EXISTS `t_dbserver`;
CREATE TABLE `t_dbserver` (
  `db_id` varchar(16) COLLATE utf8_bin NOT NULL COMMENT '运行的服务，其编码ID',
  `server_id` varchar(16) COLLATE utf8_bin DEFAULT NULL COMMENT '机器ID编码',
  `address` varchar(50) COLLATE utf8_bin DEFAULT NULL COMMENT '服务的地址，IP或域名',
  `port` int(5) DEFAULT NULL COMMENT '服务的端口，port',
  `bind_db_id` varchar(16) COLLATE utf8_bin DEFAULT NULL COMMENT '数据库主从关系中的对应的服务ID',
  `db_relation` varchar(6) COLLATE utf8_bin DEFAULT NULL COMMENT '主从关系类型：master，slave',
  `version` varchar(10) COLLATE utf8_bin DEFAULT NULL COMMENT '数据库版本号',
  `db_type` varchar(15) COLLATE utf8_bin DEFAULT NULL COMMENT '数据库程序名称：mysql、nosql、redis等',
  `db_names` tinytext COLLATE utf8_bin COMMENT '一个数据库实例中的所有库名',
  PRIMARY KEY (`db_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='记录mysql实例的表';

-- ----------------------------
-- Records of t_dbserver
-- ----------------------------
INSERT INTO `t_dbserver` VALUES ('0a4cb4e5672a563a', 'f89b9a7c7acace67', 'iamIPaddress,iamIPaddress', '3306', 'null', 'slave', '5.6.13', 'mysql', 0x636D64625F7765622C636D64625F6F73732C636D64622C);

-- ----------------------------
-- Table structure for `t_gametype`
-- ----------------------------
DROP TABLE IF EXISTS `t_gametype`;
CREATE TABLE `t_gametype` (
  `game_id` int(4) NOT NULL COMMENT '游戏类型编码ID，1001，1002，1003...',
  `game` varchar(20) COLLATE utf8_bin DEFAULT NULL COMMENT '游戏类型：C1，C2，JLMF，CSJ等',
  `type` varchar(20) COLLATE utf8_bin DEFAULT NULL COMMENT '游戏版本：国内IOS，越南版',
  PRIMARY KEY (`game_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='自定义游戏版本';

-- ----------------------------
-- Records of t_gametype
-- ----------------------------
INSERT INTO `t_gametype` VALUES ('1001', '三剑豪', '国内IOS');
INSERT INTO `t_gametype` VALUES ('1002', '三剑豪', '越南');
INSERT INTO `t_gametype` VALUES ('1003', '三剑豪', '泰国');
INSERT INTO `t_gametype` VALUES ('1004', '精灵与魔法', '国内');
INSERT INTO `t_gametype` VALUES ('1005', '三剑豪2', '国服');
INSERT INTO `t_gametype` VALUES ('1006', '绝对领域', '国内');
INSERT INTO `t_gametype` VALUES ('1007', '地下城与勇士', '国内');
INSERT INTO `t_gametype` VALUES ('1008', '长生诀', '国内');
INSERT INTO `t_gametype` VALUES ('1009', '风起长安', '国内');

-- ----------------------------
-- Table structure for `t_gs`
-- ----------------------------
DROP TABLE IF EXISTS `t_gs`;
CREATE TABLE `t_gs` (
  `gs_id` varchar(16) COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT '游戏服、世界服，自编ID',
  `server_id` varchar(16) COLLATE utf8_bin DEFAULT NULL COMMENT '游戏服与世界服所在服务器的ID',
  PRIMARY KEY (`gs_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='暂列：以后用于记录游戏服与世界服的配置，及其它关联信息';

-- ----------------------------
-- Records of t_gs
-- ----------------------------

-- ----------------------------
-- Table structure for `t_pingfailure`
-- ----------------------------
DROP TABLE IF EXISTS `t_pingfailure`;
CREATE TABLE `t_pingfailure` (
  `server_id` varchar(16) COLLATE utf8_bin NOT NULL COMMENT '机器ID编码',
  `times` int(4) DEFAULT '0' COMMENT 'ping failure 的次数统计',
  PRIMARY KEY (`server_id`),
  UNIQUE KEY `t_index_01` (`server_id`,`times`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='saltstack的ping检查失败统计';

-- ----------------------------
-- Records of t_pingfailure
-- ----------------------------

-- ----------------------------
-- Table structure for `t_program`
-- ----------------------------
DROP TABLE IF EXISTS `t_program`;
CREATE TABLE `t_program` (
  `program_id` varchar(16) COLLATE utf8_bin NOT NULL COMMENT '运行的服务，其编码ID',
  `server_id` varchar(16) COLLATE utf8_bin DEFAULT NULL COMMENT '机器ID编码',
  `program` varchar(30) COLLATE utf8_bin DEFAULT NULL COMMENT '服务名称',
  `program_path` text COLLATE utf8_bin COMMENT '服务所在目录',
  `address` varchar(50) COLLATE utf8_bin DEFAULT NULL COMMENT '服务的地址，IP或域名',
  `pid` int(8) DEFAULT NULL COMMENT '运行中的服务主pid',
  `port` int(5) DEFAULT NULL COMMENT '服务的端口，port',
  `status` int(1) NOT NULL DEFAULT '1' COMMENT '服务状态：1表示在线、0表示下线',
  PRIMARY KEY (`program_id`),
  UNIQUE KEY `t_index_01` (`program_id`,`server_id`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='用于记录服务器上运行的所有服务，以域名或IP，端口等的方式';

-- ----------------------------
-- Records of t_program
-- ----------------------------
INSERT INTO `t_program` VALUES ('0a4cb4e5672a563a', 'f89b9a7c7acace67', 'mysql', 0x2F7573722F6C6F63616C2F6D7973716C2F62696E2F6D7973716C64202D2D626173656469723D2F7573722F6C6F63616C2F6D7973716C202D2D646174616469723D2F646174612F6D7973716C2F64617461202D2D706C7567696E2D6469723D2F7573722F6C6F63616C2F6D7973716C2F6C69622F706C7567696E202D2D757365723D6D7973716C202D2D6C6F672D6572726F723D2F646174612F6D7973716C2F6C6F672F6D7973716C642E6C6F67202D2D6F70656E2D66696C65732D6C696D69743D3635353335202D2D7069642D66696C653D2F646174612F6D7973716C2F6D7973716C642E706964202D2D736F636B65743D2F646174612F6D7973716C2F646174612F6D7973716C2E736F636B202D2D706F72743D33333036, 'iamIPaddress,iamIPaddress', '4227', '3306', '1');
INSERT INTO `t_program` VALUES ('0fdd4c314feb3b1b', 'd379df63e0b6602a', 'GameServerMannage', 0x433A5C334A69616E48616F53657276657230315C47616D655365727665724D616E6E6167652E657865, 'iamIPaddress,iamIPaddress', '4548', '55642', '1');
INSERT INTO `t_program` VALUES ('356d3610ca088e68', 'd379df63e0b6602a', 'GameServerMannage', 0x433A5C334A69616E48616F53657276657230325C47616D655365727665724D616E6E6167652E657865, 'iamIPaddress,iamIPaddress', '4612', '55641', '1');
INSERT INTO `t_program` VALUES ('ba0ac295425a640c', 'c1d9e32ac1c63344', 'nginx', 0x6E67696E783A206D61737465722070726F63657373202F7573722F6C6F63616C2F6E67696E782F7362696E2F6E67696E78, 'iamIPaddress,iamIPaddress', '1972', '80', '1');
INSERT INTO `t_program` VALUES ('bac41bb7c7104abd', 'f89b9a7c7acace67', 'nginx', 0x6E67696E783A206D61737465722070726F63657373202F6F70742F6769746C61622F656D6265646465642F7362696E2F6E67696E78202D70202F7661722F6F70742F6769746C61622F6E67696E78, 'iamIPaddress,iamIPaddress', '1152', '8060', '1');

-- ----------------------------
-- Table structure for `t_saltmaster`
-- ----------------------------
DROP TABLE IF EXISTS `t_saltmaster`;
CREATE TABLE `t_saltmaster` (
  `game_id` int(4) NOT NULL DEFAULT '0',
  `server_id` varchar(16) COLLATE utf8_bin DEFAULT NULL,
  PRIMARY KEY (`game_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

-- ----------------------------
-- Records of t_saltmaster
-- ----------------------------
INSERT INTO `t_saltmaster` VALUES ('1009', 'f89b9a7c7acace67');

-- ----------------------------
-- Table structure for `t_server`
-- ----------------------------
DROP TABLE IF EXISTS `t_server`;
CREATE TABLE `t_server` (
  `server_id` varchar(16) COLLATE utf8_bin NOT NULL COMMENT '机器ID编码',
  `game_id` int(4) DEFAULT NULL COMMENT '游戏类型编码：比如C1国内IOS，C1越南，C2国内等',
  `hostname` varchar(50) COLLATE utf8_bin DEFAULT NULL COMMENT 'hostname',
  `ip` varchar(15) COLLATE utf8_bin DEFAULT NULL COMMENT '内网IP',
  `netip` varchar(15) COLLATE utf8_bin DEFAULT NULL COMMENT '外网IP',
  `os` varchar(80) COLLATE utf8_bin DEFAULT NULL COMMENT '操作系统',
  `cpu` varchar(80) COLLATE utf8_bin DEFAULT NULL COMMENT 'cpu',
  `mem` int(10) DEFAULT NULL COMMENT '内存，单位MB',
  `disk` int(10) DEFAULT NULL COMMENT '磁盘分区信息与分区容量',
  `status` int(1) DEFAULT '1' COMMENT '状态：1表示上线；0表示停用',
  `env` varchar(30) COLLATE utf8_bin DEFAULT NULL COMMENT '服务器环境类型：正式、测试、提审、预发布等',
  `saltid` varchar(50) COLLATE utf8_bin DEFAULT NULL COMMENT 'saltsatck的minion配置文件中的ID',
  `uninstanceid` varchar(20) COLLATE utf8_bin DEFAULT NULL COMMENT '腾讯云服务器api中的 unInstanceId',
  `price` float(6,2) DEFAULT NULL COMMENT '云服务器价格',
  `cvmtype` varchar(20) COLLATE utf8_bin DEFAULT NULL COMMENT '机器类型【接入\\计算\\DB\\cache\\存储】',
  `bandwidth` int(5) DEFAULT NULL COMMENT 'bandwidth，云服务器的外网出最大带宽',
  PRIMARY KEY (`server_id`),
  UNIQUE KEY `t_index_01` (`server_id`,`game_id`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='云服务器清单';

-- ----------------------------
-- Records of t_server
-- ----------------------------
INSERT INTO `t_server` VALUES ('c1d9e32ac1c63344', '1009', '', 'iamIPaddress', 'iamIPaddress', 'CentOS 6.5,Linux 2.6.32-431.el6.x86_64', 'Intel(R) Xeon(R) CPU E5-2620 v3 @ 2.40GHz[2]', '1878', '48', '1', 'PublicServer', 'centos_iamIPaddress', null, null, null, null);
INSERT INTO `t_server` VALUES ('d379df63e0b6602a', '1009', 'YW', 'iamIPaddress', 'iamIPaddress', 'Microsoft Windows Server 2008 R2 Enterprise 6.1.7601', 'Intel64 Family 6 Model 63 Stepping 2, GenuineIntel[2]', '4095', '48', '1', 'GMServer', 'win2008_test', null, null, null, null);
INSERT INTO `t_server` VALUES ('f89b9a7c7acace67', '1009', 'sjh-gsdbMater04', 'iamIPaddress', 'iamIPaddress', 'CentOS 6.8,Linux 2.6.32-642.4.2.el6.x86_64', 'Intel(R) Xeon(R) CPU E5-2620 v3 @ 2.40GHz[2]', '1877', '48', '1', 'PublicServer', 'centos_iamIPaddress', null, null, null, null);

-- ----------------------------
-- View structure for `all_services`
-- ----------------------------
DROP VIEW IF EXISTS `all_services`;
CREATE ALGORITHM=UNDEFINED DEFINER=`IamUsername`@`iamIPaddress` SQL SECURITY DEFINER VIEW `all_services` AS select `a`.`server_id` AS `server_id`,`a`.`ip` AS `ip`,`a`.`netip` AS `netip`,`a`.`cpu` AS `cpu`,`a`.`mem` AS `mem`,`a`.`disk` AS `disk`,`a`.`os` AS `os`,`a`.`game_id` AS `game_id`,`b`.`program` AS `program`,`b`.`pid` AS `pid`,`b`.`port` AS `port` from (`t_server` `a` join `t_program` `b`) where (`a`.`server_id` = `b`.`server_id`) ;
