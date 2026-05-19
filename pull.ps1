# ==============================
# 全自动上传脚本：保存聊天记录 + 推送Git
# ==============================

# 1. 自动生成 Copilot 聊天记录（永不报错）
$outFile = "$PWD\copilot_chat_history.md"
$content = @"
# VSCode Copilot 优化记录
生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## 用户
读取当前目录结构和文件内容给出优化

## GitHub Copilot 优化建议
### 项目结构
- elk: ELK 日志套件
- mysql: MySQL 服务
- nginx: 网关服务
- redis: 缓存
- backend: Go 后端
- scripts: 部署脚本
- install.sh: 主安装脚本
- .env: 环境变量

### 主要优化点
1. 统一使用 .env 环境变量，install.sh 必须 source .env
2. 修复变量判断逻辑，任一关键变量为空则退出
3. Docker Compose 添加 env_file，避免硬编码
4. 禁止 cp -rf 覆盖生产数据
5. 使用自定义 Docker 网络
6. 后端服务改为构建镜像运行，而非直接挂载源码
7. Nginx 只挂载必要目录，提升安全性
8. 增加启动顺序依赖 depends_on
9. 关闭自动 yum update
10. 所有服务使用 restart: unless-stopped

### 架构优化
- 增加根目录 docker-compose.yml 统一编排
- 完善服务依赖关系
- 提升跨平台（Windows/Linux）兼容性
"@

$content | Out-File $outFile -Encoding UTF8
Write-Host "✅ 聊天记录已保存" -ForegroundColor Green

# 2. Git 上传（你的账号已配置好）
git add .
git commit -m "代码更新 + 聊天记录"
git push origin main

Write-Host "`n✅ 全部上传完成！两台电脑已同步`n" -ForegroundColor Green
pause