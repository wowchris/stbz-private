# 维护指南

## 日常维护

### 查看服务状态

```bash
# 查看所有服务状态
docker-compose ps

# 查看特定服务日志
docker-compose logs nginx
docker-compose logs mysql
docker-compose logs redis

# 实时查看日志
docker-compose logs -f nginx
```

### 服务管理

```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 重启特定服务
docker-compose restart nginx

# 停止特定服务
docker-compose stop mysql

# 启动特定服务
docker-compose start mysql
```

## 备份与恢复

### 创建备份脚本

创建备份脚本 `backup.sh`：

```bash
#!/bin/bash

# 备份脚本
BACKUP_DIR="/backup/private"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "开始备份..."

# 备份数据库
docker exec mysql5.7 mysqldump -u root -p${DB_PASSWORD} --all-databases > $BACKUP_DIR/mysql_backup_$DATE.sql

# 备份配置文件
tar -czf $BACKUP_DIR/config_backup_$DATE.tar.gz .env docker-compose.yml ./services/

echo "备份完成: $BACKUP_DIR"
```

### 恢复数据

```bash
# 恢复数据库备份
docker exec -i mysql5.7 mysql -u root -p${DB_PASSWORD} < backup_file.sql
```

## 性能监控

### 资源使用情况

```bash
# 查看容器资源使用
docker stats

# 查看特定容器资源使用
docker stats $(docker-compose ps -q)
```

### 日志管理

```bash
# 清理日志文件
docker-compose logs --tail 100 > recent_logs.txt

# 清理Docker系统
docker system prune -f
docker volume prune -f
```

## 更新与升级

### 更新服务

```bash
# 拉取最新镜像
docker-compose pull

# 重建并启动服务
docker-compose up -d --build
```

### 版本管理

- 记录每次更新的版本号
- 在更新前备份当前配置
- 测试更新后功能正常

## 安全维护

### 密码管理

- 定期更换数据库密码
- 定期更换Redis密码
- 定期更换Elasticsearch密码

### 访问控制

- 限制对管理端口的访问
- 使用防火墙规则保护服务端口
- 定期检查服务日志中的异常访问

## 故障恢复

### 服务重启策略

- 单个服务故障：自动重启
- 多个服务故障：检查依赖关系后逐个重启
- 整体故障：使用备份恢复

### 紧急联系方式

- 系统管理员：[联系信息]
- 技术支持：[联系信息]

## 监控告警

### 关键指标

- CPU使用率
- 内存使用率
- 磁盘空间
- 网络连接数
- 服务响应时间

### 告警阈值

- CPU使用率 > 80%
- 内存使用率 > 85%
- 磁盘空间 < 20%可用
- 服务无响应 > 30秒