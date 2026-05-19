#!/bin/sh
# 清理go日志,默认保留3天
# 0 1 * * * /bin/sh /usr/src/privateLogClear.sh >/dev/null 2>&1


logFile='/data/project/backend/logs'


find ${logFile} -ctime +1 -type f -exec rm -rf {} \;  >/dev/null 2>&1

logs=$(find /var/lib/docker/containers/ -name *-json.log)

for log in $logs
        do
                echo "clean logs : $log"
                cat /dev/null > $log
        done

