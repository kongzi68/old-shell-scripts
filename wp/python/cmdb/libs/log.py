# coding=utf-8
import time
import os
import logging
import logging.config
import yaml

class Formatter(logging.Formatter):
    def formatTime(self, record, datefmt=None):
        """
        formatTime Method rewrite
        """
        ct = self.converter(record.created)
        if datefmt:
            s = time.strftime(datefmt, ct)
        else:
            nano_seconds = format(time.time(),'0.10f')
            nano_seconds = str(nano_seconds).split('.')[1]
            t = time.strftime("%Y-%m-%d %H:%M:%S", ct)
            s = "{0},{1}".format(t, nano_seconds)
        return s

def setup_logging(default_path='config/logging.yaml', default_level=logging.INFO):
    """
    Setup logging configuration
    """
    path = default_path
    if os.path.exists(path):
        with open(path, 'rt') as f:
            config = yaml.load(f.read())
        logging.config.dictConfig(config)
        # set log microseconds
        fmt = "%(asctime)s %(levelname)s %(module)s-%(lineno)d::%(message)s"
        formatter = Formatter(fmt, datefmt=None)
        for handler in logging.getLogger().handlers:
            handler.setFormatter(formatter)
    else:
        logging.basicConfig(level=default_level)

