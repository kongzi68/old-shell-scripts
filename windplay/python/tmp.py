def addmonth(month_str, n = 1):
    '''
    :param month_str:  "2016-05"
    :param n:  default n = 1
    :return:  "2016-06"
    '''
    datetime1 = datetime.datetime.strptime(month_str, "%Y-%m")
    one_day = datetime.timedelta(days = 1)
    q,r = divmod(datetime1.month + n, 12)
    datetime2 = datetime.datetime(datetime1.year + q, r + 1, 1) - one_day

    return '{0}-{1}'.format(datetime2.year, datetime2.month)

#-------------------------
Python 2.7.3 (default, Feb 27 2014, 19:58:35) 
[GCC 4.6.3] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> import tab
>>> import test
>>> test.addmonth("2017-05", 5)
'2017-10'
>>> test.addmonth("2016-11", 5)   
'2017-4'
>>> test.addmonth("2016-11", -1)
'2016-10'
>>> test.addmonth("2016-11", -11)
'2015-12'
>>> test.addmonth("2016-11", -13)
'2015-10'
>>> 