#!/bin/env python
import MySQLdb
def read_host():
        "this is for reading GSDB host and port"
	try:
		hostList = []
		conn = MySQLdb.connect(host='iamIPaddress',user='IamUsername',passwd='123456',db='Login',port=3306,charset='utf8')
		cur = conn.cursor()
		sql = "SELECT DISTINCT dbip,dbport,dbname FROM t_gameserver_list ORDER BY real_sid;"
		cur.execute(sql)
		for data in cur.fetchall():
			hostList.append(list(data))
		cur.close()
		conn.close()
		return hostList
	except MySQLdb.Error,e:
		print "MySQL Error %d:%s"%(e.args[0],e.args[1])

if __name__ == '__main__':
	for host in read_host():
		print host
