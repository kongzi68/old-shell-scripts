#!/usr/bin/env python
#coding=utf-8
import psutil
# python2.6.6 未自带此模块

def getDisk():
    ret = {}
    try:
        tdisk = psutil.disk_partitions()
        disk_total = 0
        for i in range(0, len(tdisk)):
            mountpoint = tdisk[i].mountpoint
            disk_total += psutil.disk_usage(mountpoint).total
    except Exception:
        pass
        
    ret['disk'] = disk_total/1000/1000/1000
    return ret
