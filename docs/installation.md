# Private 项目安装指南

## 系统要求

- 操作系统：CentOS 7+, Alibaba Cloud Linux, Ubuntu 18.04+
- 内存：至少 4GB RAM（推荐 8GB+）
- 存储：至少 20GB 可用空间
- Docker: 19.03+
- Docker Compose: 1.25+

## 安装步骤

### 1. 环境准备

```bash
# 克隆项目
git clone <your-repo-url>
cd private

# 复制环境变量示例文件
cp .env.example .env
```

### 2. 配置环境变量

编辑 `.env` 文件，配置以下参数：

```bash
# 编辑环境变量文件
vim .env
```

关键配置项说明：
- `DOMAINNAME`: 项目域名
- `DB_PASSWORD`: MySQL数据库密码
- `REDIS_PASSWORD`: Redis密码
- `ELASTIC_PASSWORD`: Elasticsearch密码
- `MOUNTED_SHARED_DIRECTORY`: 数据挂载目录（默认为 `/data`）

### 3. 启动服务

#### 方法一：使用一键安装脚本
```bash
# 确保脚本具有执行权限
chmod +x install.sh

# 运行安装脚本
sudo bash install.sh
```

#### 方法二：手动启动服务
```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

### 4. 验证安装

```bash
# 检查所有容器是否正常运行
docker-compose ps

# 检查服务日志
docker-compose logs nginx
docker-compose logs mysql
docker-compose logs redis
```

## 服务端口说明

| 服务 | 端口 | 说明 |
|------|------|------|
| Nginx | 80, 443 | Web服务器 |
| MySQL | 3306 | 数据库 |
| Redis | 6379 | 缓存 |
| NSQ | 4150, 4151, 4160, 4161, 4171 | 消息队列 |
| Elasticsearch | 9200, 9300 | 搜索引擎 |
| Kibana | 5601 | 数据可视化 |
| Private App | 8199 | 私有应用 |

## 常见问题

### 1. 权限问题
如果遇到权限问题，请确保：
- 以管理员权限运行安装脚本
- Docker服务已启动
- 用户在docker组中

### 2. 端口冲突
如果遇到端口冲突，请检查：
- 确认所需端口未被其他服务占用
- 修改docker-compose.yml中的端口映射

### 3. 存储空间不足
请确保有足够的磁盘空间用于：
- Docker镜像存储
- 服务数据持久化
- 日志文件存储