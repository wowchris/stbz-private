#!/bin/bash
# 以守护进程模式启动 Redis 服务并设置密码
redis-server --requirepass middleground2022 --daemonize yes
# 带密码选择 3 号数据库
redis-cli -a middleground2022 SELECT 3
# 带密码执行 hmset 命令
redis-cli -a middleground2022 HMSET   SOURCE:TYPE  1 云仓 2 鲸选 6 阿里 7 天猫 8 苏宁 11 自营云仓 12 特卖一仓 14 华东一仓 16 跨境一仓 17 天猫精选 18 厂家直销 19 云仓优选 20 天猫优选 21 苏宁易购
# 保持容器运行
tail -f /dev/null
