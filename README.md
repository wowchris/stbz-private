# Private 项目

## 项目概述

Private 是一个多服务的容器化应用项目，支持 CentOS、Alibaba Cloud Linux 和 Ubuntu 系统。该项目提供了一键部署解决方案，包含 Nginx、MySQL、Redis、NSQ、ELK 和私有应用服务。

## 核心特性

- **跨平台支持**: 自动识别 CentOS、Alibaba Cloud Linux、Ubuntu 系统
- **统一配置管理**: 所有变量和密码由 .env 文件统一调用
- **服务编排**: 使用 Docker Compose 进行统一服务管理
- **网络隔离**: 实现前端、后端和监控网络隔离
- **资源限制**: 对各服务设置合理的资源限制
- **健康检查**: 集成服务健康检查机制

## 项目结构

```
private/
├── .env                    # 环境变量配置
├── .env.example           # 环境变量示例
├── docker-compose.yml     # 主编排文件
├── install.sh            # 一键安装脚本
├── README.md             # 项目说明
├── CHANGELOG.md          # 变更日志
├── STRUCTURE_OPTIMIZATION_PLAN.md # 结构优化方案
├── docs/                 # 文档目录
│   ├── installation.md   # 安装指南
│   ├── configuration.md  # 配置说明
│   ├── troubleshooting.md # 故障排除
│   └── maintenance.md    # 维护指南
├── scripts/              # 脚本目录
├── services/             # 服务配置目录
│   ├── nginx/            # Nginx服务配置
│   ├── mysql/            # MySQL服务配置
│   ├── redis/            # Redis服务配置
│   ├── nsq/              # NSQ消息队列配置
│   ├── elk/              # ELK栈配置
│   └── backend/          # 后端应用配置
└── data/                 # 数据持久化目录
```

## 快速开始

### 1. 环境准备

```bash
# 克隆项目
git clone <your-repo-url>
cd private

# 复制环境变量文件
cp .env.example .env

# 根据需要编辑环境变量
vim .env
```

### 2. 一键安装

```bash
# 确保脚本具有执行权限
chmod +x install.sh

# 运行安装脚本（需要sudo权限）
sudo bash install.sh
```

### 3. 验证安装

```bash
# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs

# 访问应用
curl http://<your-domain-or-ip>
```

## 服务列表

| 服务 | 端口 | 用途 |
|------|------|------|
| Nginx | 80, 443 | Web服务器和反向代理 |
| MySQL | 3306 | 数据库服务 |
| Redis | 6379 | 缓存服务 |
| NSQ | 4150-4171 | 消息队列服务 |
| Elasticsearch | 9200, 9300 | 搜索和分析引擎 |
| Kibana | 5601 | 数据可视化工具 |
| Private App | 8199 | 私有业务应用 |

## 配置管理

所有服务配置都通过 `.env` 文件进行管理：

```bash
# 必需配置项
DOMAINNAME=your-domain.com
DB_PASSWORD=your-db-password
REDIS_PASSWORD=your-redis-password
ELASTIC_PASSWORD=your-elastic-password

# 可选配置项
MOUNTED_SHARED_DIRECTORY=/data
DB_DATABASE=middleground
DB_USER=root
```

## 维护管理

### 服务管理

```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 重启特定服务
docker-compose restart nginx

# 查看服务日志
docker-compose logs -f nginx
```

## 文档

完整文档请参阅 `docs/` 目录：

- [安装指南](./docs/installation.md)
- [配置说明](./docs/configuration.md)
- [故障排除](./docs/troubleshooting.md)
- [维护指南](./docs/maintenance.md)

## 安全注意事项

- 生产环境中请勿使用默认密码
- 定期更新环境变量中的密码
- 限制对管理端口的访问
- 定期检查系统日志

## 许可证

[在此处添加许可证信息]
