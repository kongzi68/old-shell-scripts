/*
Navicat MySQL Data Transfer

Source Server         : iamIPaddress
Source Server Version : 50613
Source Host           : iamIPaddress:3306
Source Database       : cmdb_web

Target Server Type    : MYSQL
Target Server Version : 50613
File Encoding         : 65001

Date: 2018-01-17 17:38:31
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for `users`
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(80) COLLATE utf8_bin NOT NULL,
  `password` varchar(200) COLLATE utf8_bin NOT NULL,
  `status` enum('NORMAL','LIMIT') COLLATE utf8_bin DEFAULT NULL,
  `is_valid` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updateed_at` datetime DEFAULT NULL,
  `last_login` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

-- ----------------------------
-- Records of users
-- ----------------------------
INSERT INTO `users` VALUES ('1', 'admin', 'pbkdf2:sha256:50000$C2KzOBLR$303f1c9b9a5acd350db8a3d25c0f45fa89488eee43ad9ba1199e9c48c3965792', null, '1', '2018-01-11 14:45:33', null, '2018-01-11 17:24:33');
