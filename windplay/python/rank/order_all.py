#!/usr/bin/env python
# -*- coding: utf-8 -*-
import time
import thread
import MySQLdb
from read_host import read_host
def update_order(db_ip,db_port,db_name,lock):
    try:
        conn = MySQLdb.connect(host=db_ip,user='root',passwd='123456',db=db_name,port=db_port,charset='utf8')
        cur = conn.cursor()
        cur.execute("call rank_attdef")
        conn.commit()
        time.sleep(5)
        cur.execute("call rank_equip")
        conn.commit()
        time.sleep(5)
        cur.execute("call rank_shengwang")
        conn.commit()
        time.sleep(5)
        cur.execute("call rank_tower")
        conn.commit()
        time.sleep(5)
        cur.execute("call rank_warrior")
        conn.commit()
        conn.close()
    except MySQLdb.Error,e:
        print "MySQL Error %d:%s"%(e.args[0],e.args[1])		
    finally:
        lock.release()
def main():
    hostlist = read_host()
    locks = []
    n = 0
    for i in range(len(hostlist)):
        lock = thread.allocate_lock() 
        lock.acquire() 
        locks.append(lock)
    for host in hostlist:
        thread.start_new_thread(update_order,(host[0],host[1],host[2],locks[n]))
        n += 1
    for i in range(len(hostlist)):
        while locks[i].locked():
            pass
#    print 'all done at:',time.ctime()

if __name__ == "__main__":
    main()
