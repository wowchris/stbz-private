#!/bin/sh
# 清理go日志,默认保留3天
# 0 1 * * * /bin/sh /usr/src/privateLogClear.sh >/dev/null 2>&1


logFile='/data/project/backend/logs'


find ${logFile} -mtime +3 -type f -exec rm -rf {} \; 
