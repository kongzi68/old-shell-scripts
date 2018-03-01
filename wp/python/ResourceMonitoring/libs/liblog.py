# coding=utf-8
import time
import os
import logging
import logging.config
import yaml


LEVEL_COLOR = {
    logging.DEBUG: '\33[0;39m',
    logging.INFO: '\33[0;37m',
    logging.WARN: '\33[0;35m',
    logging.ERROR: '\33[0;31m',
    logging.FATAL: '\33[7;31m'
}


class ScreenHandler(logging.StreamHandler):
    def emit(self, record):
        try:
            msg = self.format(record)
            stream = self.stream
            fs = LEVEL_COLOR[record.levelno] + "%s\n" + '\33[0m'
            try:
                if isinstance(msg, unicode) and getattr(stream, 'encoding', None):
                    ufs = fs.decode(stream.encoding)
                    try:
                        stream.write(ufs % msg)
                    except UnicodeEncodeError:
                        stream.write((ufs % msg).encode(stream.encoding))
                else:
                    stream.write(fs % msg)
            except UnicodeError:
                stream.write(fs % msg.encode("UTF-8"))

            self.flush()
        except (KeyboardInterrupt, SystemExit):
            raise
        except:
            self.handleError(record)

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
        # fmt = "%(asctime)s %(levelname)s %(module)s-%(lineno)d::%(message)s"
        fmt = config['formatters']['simple']['format'] # 重设格式
        formatter = Formatter(fmt, datefmt=None)
        for handler in logging.getLogger().handlers:
            handler.setFormatter(formatter)
    else:
        logging.basicConfig(level=default_level)

