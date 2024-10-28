/*
Navicat MySQL Data Transfer

Source Server         : iamIPaddress
Source Server Version : 50613
Source Host           : iamIPaddress:3306
Source Database       : cmdb_oss

Target Server Type    : MYSQL
Target Server Version : 50613
File Encoding         : 65001

Date: 2018-01-17 17:38:23
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for `t_config`
-- ----------------------------
DROP TABLE IF EXISTS `t_config`;
CREATE TABLE `t_config` (
  `id` varchar(16) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `game_id` int(11) DEFAULT NULL,
  `custom_name` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `servers` text CHARACTER SET utf8 COLLATE utf8_bin,
  `conf_name` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `conf_save_name` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `conf_data` text CHARACTER SET utf8 COLLATE utf8_bin,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Records of t_config
-- ----------------------------
INSERT INTO `t_config` VALUES ('2ed6d5c944d8462f', '1009', 'PublicServer', 0x633164396533326163316336333334342C66383962396137633761636163653637, 'config.properties', '2ed6d5c944d8462f.properties', 0x633164396533326163316336333334342C2F686F6D652F6A74796C2F636F6E662F636F6E6669672E70726F706572746965732C313B0D0A663839623961376337616361636536372C2F646174612F6A74796C2F636F6E662F636F6E6669672E70726F706572746965732C323B);

-- ----------------------------
-- Table structure for `t_config_dict`
-- ----------------------------
DROP TABLE IF EXISTS `t_config_dict`;
CREATE TABLE `t_config_dict` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `conf_id` varchar(16) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `server_id` varchar(16) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `conf_path` varchar(200) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

-- ----------------------------
-- Records of t_config_dict
-- ----------------------------
INSERT INTO `t_config_dict` VALUES ('1', '2ed6d5c944d8462f', 'c1d9e32ac1c63344', '/home/jtyl/conf/config.properties');
INSERT INTO `t_config_dict` VALUES ('2', '2ed6d5c944d8462f', 'f89b9a7c7acace67', '/data/jtyl/conf/config.properties');
