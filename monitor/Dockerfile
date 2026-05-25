# 单阶段稳定构建（国内环境专用）
FROM golang:1.24-alpine3.19

# 你要的核心环境变量 ✅
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    GO111MODULE=on \
    GOPROXY=https://goproxy.cn,direct

WORKDIR /app

# 安装依赖
RUN apk add --no-cache git docker-cli

# 复制项目文件
COPY . .

# 构建（完全静态编译）
RUN go mod tidy && \
    go build -a -ldflags '-w -s' -o monitor .

# 暴露端口
EXPOSE 9999

# 启动
CMD ["./monitor"]
