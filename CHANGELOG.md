# 变更日志

## [优化版] - 2026-05-23

### 新增
- 创建项目结构优化方案文档 (STRUCTURE_OPTIMIZATION_PLAN.md)
- 添加完整的文档目录结构 (docs/)
- 添加详细的安装指南 (docs/installation.md)
- 添加配置说明文档 (docs/configuration.md)
- 添加故障排除指南 (docs/troubleshooting.md)
- 添加维护操作指南 (docs/maintenance.md)
- 创建优化版安装脚本 (install_optimized.sh)
- 创建统一的 docker-compose.yml 文件
- 创建优化版 README (README_OPTIMIZED.md)
- 创建标准的 CHANGELOG 文件

### 改进
- 重构 docker-compose.yml 文件，增加网络隔离、健康检查、资源限制等功能
- 增强安装脚本的错误处理和系统兼容性检查
- 统一服务配置管理，提高可维护性
- 改进环境变量验证机制
- 优化服务依赖关系和启动顺序

### 修复
- 修复了原始安装脚本中的一些潜在问题
- 改进了服务间的网络通信配置
- 优化了数据持久化路径

---

## [初始版本] - 早期版本

### 功能
- 支持 CentOS、Alibaba Cloud Linux、Ubuntu 系统识别
- 通过 .env 文件统一管理所有环境变量
- 支持 Nginx、MySQL、Redis、NSQ、ELK、私有应用等服务
- 提供一键部署脚本 install.sh