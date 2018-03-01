#!/usr/bin/env python
#coding=utf-8
#Scripts web autonomously manages platform(SWAMP)
import logging
import os
from swamp import app, db
from swamp.main.libs import liblog
from flask_script import Manager, Shell
from flask_migrate import Migrate, MigrateCommand


liblog.setup_logging()
logger = logging.getLogger(__name__)
logger.info('Running.')

manager = Manager(app)
migrate = Migrate(app, db)

def make_shell_context():
    return dict(app=app, db=db)

# make_shell_context() 函数注册了程序、数据库实例以及模型，因此这些对象能直接导入 shell
# python manage.py shell
manager.add_command("shell", Shell(make_context=make_shell_context))
manager.add_command('db', MigrateCommand)

if not os.path.exists('./log'):
    os.mkdir('./log')

if __name__ == '__main__':
    manager.run()

