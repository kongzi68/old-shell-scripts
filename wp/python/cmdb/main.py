#!/usr/bin/env python
# coding=utf-8
import logging
import os
import sys
import warnings
from libs import log
from modules import t_server
from modules import t_program
from modules import t_dbserver

log.setup_logging()
logger = logging.getLogger(__name__)
warnings.filterwarnings('ignore')

def getHelp():
    logger.error("Usage: python {0} -h|--help, get help.".format(sys.argv[0]))
    sys.exit()

if __name__ == '__main__':
    if not os.path.exists('./log'):
        os.mkdir('./log')
    logger.info('Running.')

    if len(sys.argv) == 1:
        t_server.execMainCheck()
        t_program.execMainCheck()
        t_dbserver.execMainCheck()
    elif len(sys.argv) == 2:
        if sys.argv[1] in ['-h', '--help']:
            logger.info("Usage: python {0} -G group_names".format(sys.argv[0]))
            logger.info("    get cmdb info by saltstack`s nodegroups.")
            logger.info("Usage: python {0} -g minion_id".format(sys.argv[0]))
            logger.info("    get cmdb info by saltstack`s nodegroups.")
        else:
            getHelp()
    elif len(sys.argv) == 3:
        if sys.argv[1] == '-G':
            run_status = t_server.execMainCheck(opt=sys.argv[2], opt_name='group')
            if not run_status:
                logger.error('Please check that the input parameters are correct.')
                getHelp()
            t_program.execMainCheck(opt=sys.argv[2], opt_name='group')
            t_dbserver.execMainCheck(opt=sys.argv[2], opt_name='group')
        elif sys.argv[1] == '-g':
            run_status = t_server.execMainCheck(opt=sys.argv[2], opt_name='only')
            if not run_status:
                logger.error('Please check that the input parameters are correct.')
                getHelp()
            t_program.execMainCheck(opt=sys.argv[2], opt_name='only')
            t_dbserver.execMainCheck(opt=sys.argv[2], opt_name='only')
        else:
            getHelp()
    else:
        getHelp()

    logger.info('Done.')
