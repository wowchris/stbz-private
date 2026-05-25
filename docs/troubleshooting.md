# 故障排除指南

## 通用排查步骤

### 1. 检查服务状态
```bash
# 查看所有服务状态
docker-compose ps

# 查看特定服务日志
docker-compose logs <service-name>
```

### 2. 检查系统资源
```bash
# 检查磁盘空间
df -h

# 检查内存使用
free -h

# 检查CPU使用
top
```

## 常见问题及解决方案

### 1. Docker服务未启动
**症状**: `docker: command not found` 或 `Cannot connect to the Docker daemon`
**解决方案**:
```bash
# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 检查Docker服务状态
sudo systemctl status docker
```

### 2. 端口被占用
**症状**: `Bind for 0.0.0.0:80 failed: port is already allocated`
**解决方案**:
```bash
# 查找占用端口的进程
sudo netstat -tulpn | grep :80
sudo lsof -i :80

# 停止占用端口的服务或修改docker-compose.yml中的端口映射
```

### 3. MySQL启动失败
**症状**: MySQL容器反复重启或无法启动
**解决方案**:
```bash
# 检查MySQL错误日志
docker-compose logs mysql

# 检查数据目录权限
ls -la /data/mysql/data/

# 重置MySQL数据（注意：这会删除所有数据）
sudo rm -rf /data/mysql/data/*
docker-compose up -d mysql
```

### 4. Nginx配置错误
**症状**: Nginx无法启动或返回502错误
**解决方案**:
```bash
# 检查Nginx配置语法
docker-compose exec nginx nginx -t

# 查看Nginx错误日志
docker-compose logs nginx

# 重新加载Nginx配置
docker-compose exec nginx nginx -s reload
```

### 5. 环境变量未生效
**症状**: 服务使用默认配置而非.env文件中的配置
**解决方案**:
```bash
# 确保.env文件在正确的目录中
ls -la .env

# 重建服务以应用环境变量
docker-compose down
docker-compose up -d
```

### 6. 网络连接问题
**症状**: 服务之间无法通信
**解决方案**:
```bash
# 检查Docker网络
docker network ls
docker network inspect <network-name>

# 测试服务间连通性
docker-compose exec nginx ping mysql
```

### 7. 存储权限问题
**症状**: 服务因权限问题无法写入数据
**解决方案**:
```bash
# 检查数据目录权限
ls -la /data/

# 修正数据目录权限
sudo chown -R $(whoami):$(whoami) /data/
sudo chmod -R 755 /data/
```

## 诊断命令

### 检查整体系统状态
```bash
# 检查Docker系统信息
docker info

# 检查Docker版本
docker --version
docker-compose --version

# 检查所有容器状态
docker ps -a

# 检查系统资源使用
docker stats
```

### 服务特定诊断
```bash
# 检查MySQL连接
docker-compose exec mysql mysql -u root -p${DB_PASSWORD} -e "SHOW DATABASES;"

# 检查Redis连接
docker-compose exec redis redis-cli -a ${REDIS_PASSWORD} ping

# 检查Elasticsearch状态
curl http://localhost:9200/_cluster/health?pretty

# 检查NSQ服务
curl http://localhost:4151/ping
```

## 重置和恢复

### 完全重置环境
```bash
# 停止并删除所有容器
docker-compose down -v

# 删除所有相关镜像（可选）
docker rmi $(docker images -q)

# 清理孤立容器
docker container prune -f

# 重新启动服务
docker-compose up -d
```

### 仅重启特定服务
```bash
# 重启单个服务
docker-compose restart <service-name>

# 重建并重启服务
docker-compose up --build -d <service-name>
```

## 性能问题排查

### 高CPU使用率
```bash
# 查看容器资源使用
docker stats

# 检查慢查询日志（MySQL）
docker-compose exec mysql tail -f /var/log/mysql/slow.log
```

### 高内存使用率
- 检查服务的内存限制配置
- 调整Java堆大小（如果有Java服务）
- 检查是否有内存泄漏

### 磁盘空间不足
```bash
# 检查Docker磁盘使用
docker system df

# 清理未使用的Docker对象
docker system prune -a
```