#!/usr/bin/env python
#coding=utf-8
# get net ip
import commands

def get_netip():
    ret = {}
    try:
        r = commands.getoutput('curl http://ipv4.icanhazip.com').split('\n')
        ret['netip'] = r[-1]
    except Exception:
        pass

    return ret
