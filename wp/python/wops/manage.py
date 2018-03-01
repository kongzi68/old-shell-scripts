#!/usr/bin/env python
#coding=utf-8
#Windplay Operation System(WOPS)
import logging
import os
from dotenv import load_dotenv
from ops import create_app, db
from ops.libs import liblog
from flask_script import Manager, Shell
from flask_migrate import Migrate, MigrateCommand


dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path)
if not os.path.exists('log'):
    os.mkdir('log')
liblog.setup_logging()
logger = logging.getLogger(__name__)
logger.info('Running.')

app = create_app(os.getenv('FLASK_CONFIG') or 'default')
manager = Manager(app)
migrate = Migrate(app, db)


def make_shell_context():
    return dict(app=app, db=db)

# make_shell_context() 函数注册了程序、数据库实例以及模型，因此这些对象能直接导入 shell
# python manage.py shell
manager.add_command("shell", Shell(make_context=make_shell_context))
manager.add_command('db', MigrateCommand)

if __name__ == '__main__':
    manager.run()


