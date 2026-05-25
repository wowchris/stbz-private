# 配置说明

## 环境变量配置

项目使用 `.env` 文件进行环境变量配置。请参考 `.env.example` 文件创建自己的 `.env` 文件。

### 必需的环境变量

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `DOMAINNAME` | 应用域名 | example.com |
| `DB_DATABASE` | MySQL数据库名 | middleground |
| `DB_USER` | MySQL用户名 | root |
| `DB_PASSWORD` | MySQL用户密码 | middleground2022 |
| `DB_ROOT_PASSWORD` | MySQL root密码 | root |
| `REDIS_PASSWORD` | Redis密码 | middleground2022 |
| `ELASTIC_VERSION` | Elasticsearch版本 | 7.7.0 |
| `ELASTIC_PASSWORD` | Elasticsearch密码 | middleground2022 |
| `LOGSTASH_INTERNAL_PASSWORD` | Logstash内部密码 | middleground2022 |
| `KIBANA_SYSTEM_PASSWORD` | Kibana系统密码 | middleground2022 |

### 可选的环境变量

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `MOUNTED_SHARED_DIRECTORY` | 共享挂载目录 | /data |
| `PRO_DIR` | 项目目录 | /data/project |
| `MYSQL_DIR` | MySQL数据目录 | /data/mysql |
| `REDIS_DIR` | Redis数据目录 | /data/redis |
| `ELK_DIR` | ELK数据目录 | /data/elk |
| `TIMEZONE` | 时区设置 | UTC |

## 服务配置

### Nginx配置

- 配置文件位置：`/data/nginx/nginx.conf`
- 虚拟主机配置：`/data/nginx/vhost/`
- 日志目录：`/data/nginx/logs/`
- 静态文件目录：`/data/nginx/html/`

### MySQL配置

- 数据目录：`/data/mysql/data/`
- 配置文件：`/data/mysql/conf/my.cnf`
- 日志目录：`/data/mysql/log/`

### Redis配置

- 数据目录：`/data/redis/data/`
- 配置文件：`/data/redis/redis.conf`

### ELK配置

- Elasticsearch配置：`/data/elk/elasticsearch/config/elasticsearch.yml`
- Kibana配置：`/data/elk/kibana/config/kibana.yml`
- Logstash配置：`/data/elk/logstash/config/`

## 网络配置

项目使用以下网络进行服务隔离：

- `frontend`: 前端服务网络（Nginx、Kibana等面向用户的）
- `backend`: 后端服务网络（MySQL、Redis、私有应用等）
- `monitoring`: 监控服务网络（Elasticsearch、其他监控组件）

## 存储卷配置

使用命名卷进行数据持久化：

- `mysql_data`: MySQL数据存储
- `redis_data`: Redis数据存储
- `es_data`: Elasticsearch数据存储
- `nsq_data1`, `nsq_data2`: NSQ数据存储