package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"
)

type Config struct {
	WebUsername         string           `json:"web_username"`
	WebPassword         string           `json:"web_password"`
	MaxNSQDepth         int64            `json:"max_nsq_depth"`
	MaxCPUPercent       int64            `json:"max_cpu_percent"`
	MaxMemMB            int64            `json:"max_mem_mb"`
	CheckInterval       int              `json:"check_interval"`
	DockerCheckInterval int              `json:"docker_check_interval"`
	AlertEmail          string           `json:"alert_email"`
	AlertWebhook        string           `json:"alert_webhook"`
	Services            ServicesConfig   `json:"services"`
}

type ServicesConfig struct {
	Nginx struct {
		URL     string `json:"url"`
		Timeout int    `json:"timeout"`
	} `json:"nginx"`
	Redis struct {
		Address string `json:"address"`
		Timeout int    `json:"timeout"`
	} `json:"redis"`
	NSQ struct {
		URL     string `json:"url"`
		Timeout int    `json:"timeout"`
	} `json:"nsq"`
	Elasticsearch struct {
		URL     string `json:"url"`
		Timeout int    `json:"timeout"`
	} `json:"elasticsearch"`
}

var (
	config Config
)

func loadConfig() {
	data, err := os.ReadFile("config.json")
	if err != nil {
		log.Fatal("Failed to read config:", err)
	}
	if err := json.Unmarshal(data, &config); err != nil {
		log.Fatal("Failed to parse config:", err)
	}
}

func main() {
	loadConfig()
	
	// 初始化默认值
	if config.CheckInterval == 0 {
		config.CheckInterval = 5
	}
	if config.DockerCheckInterval == 0 {
		config.DockerCheckInterval = 10
	}
	if config.MaxCPUPercent == 0 {
		config.MaxCPUPercent = 80
	}
	if config.MaxMemMB == 0 {
		config.MaxMemMB = 1024
	}
	if config.MaxNSQDepth == 0 {
		config.MaxNSQDepth = 10000
	}

	// 初始化上下文用于优雅关闭
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	log.Println("✅ Monitor service starting...")

	// 启动监控服务
	go MonitorDockerContainers(ctx)
	go MonitorServices(ctx)

	// 处理优雅关闭
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	
	go func() {
		<-sigChan
		log.Println("Received shutdown signal, stopping monitor...")
		cancel()
	}()

	StartWebServer()
}