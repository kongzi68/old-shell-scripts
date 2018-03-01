#!/usr/bin/python
#coding=utf-8

import enum
import re

class UserStatusEnum(enum.Enum):
    """ 用户状态 """
    NORMAL = "1"
    LIMIT = "2"


class PermsEnum(enum.Enum):
    """ 权限 """
    READ = "1"
    WEIBO = "2"
    COMMENT = "3"
    ADMIN = '4'


# 邮箱正则
EMAIL_PATTERN = re.compile(
    r'(?:^|\s)[-a-z0-9_.]+@(?:[-a-z0-9]+\.)+[a-z]{2,6}(?:\s|$)', re.IGNORECASE)

# Unicode字符, 数字、字母_-中文
UNICODE_PATTERN = r'^[a-zA-Z0-9_\-\u4e00-\u9fa5]+$'
# @用户
AT_USER_PATTEN = r'@(?P<user>[a-zA-Z0-9_\-\u4e00-\u9fa5]+)'
# 话题
TOPIC_PATTEN = r'#(?P<topic>[a-zA-Z0-9_\-\u4e00-\u9fa5]+)#'