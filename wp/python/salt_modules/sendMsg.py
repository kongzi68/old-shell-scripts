#!/usr/bin/env python
#coding=utf-8

import psutil
import win32api
import win32gui
import win32con

import sys
reload(sys)
sys.setdefaultencoding('utf-8')

# 枚举窗体控件的回调函数
def call_back(self, hwnd, hwnds):
    if win32gui.IsWindowVisible(hwnd) and win32gui.IsWindowEnabled(hwnd):
        hwnds['hwnd'] = hwnd
        hwnds['title'] = win32gui.GetWindowText(hwnd)
        hwnds['clsname'] = win32gui.GetClassName(hwnd)
    return True

# 发送信息
def send_string(hwnd, msg):
    # 发送字符串
    for item in msg:
        win32api.SendMessage(hwnd, win32con.WM_CHAR, ord(item), 0)
    # 发送回车键
    win32api.PostMessage(hwnd, win32con.WM_KEYDOWN, win32con.VK_RETURN, 0)
    win32api.PostMessage(hwnd, win32con.WM_KEYUP, win32con.VK_RETURN, 0)

ps_list = ['GameServerMannage.exe','WerFault.exe','GameServer.exe']
for ps_item in psutil.process_iter():
    if ps_item.name() in ps_list:
        # 查找主窗口的句柄
        gsm_hwnd = win32gui.FindWindow('ConsoleWindowClass', ps_item.exe())
        print gsm_hwnd,ps_item.pid,ps_item.name(),ps_item.exe()
        # 测试向窗口发消息
        # send_string(gsm_hwnd, 'stop')
        # 获取子窗口的句柄等信息
        try:
            hwnds = {}
            win32gui.EnumChildWindows(gsm_hwnd, call_back, hwnds)
            print hwnds['hwnd'], hwnds['title'], hwnds['clsname']
        except Exception as e:
            print e

