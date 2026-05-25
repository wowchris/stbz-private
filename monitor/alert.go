package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

// 检查容器资源使用情况
func CheckAlert(item ContainerStatus) {
	alerts := []string{}

	// 检查容器状态
	if item.State != "running" {
		alerts = append(alerts, fmt.Sprintf("Container %s is %s", item.Name, item.State))
	}

	// 检查 CPU 使用率
	if item.CPU > float64(config.MaxCPUPercent) {
		alerts = append(alerts, fmt.Sprintf("Container %s CPU usage %.1f%% exceeds threshold %d%%", 
			item.Name, item.CPU, config.MaxCPUPercent))
	}

	// 检查内存使用量
	if item.Memory > float64(config.MaxMemMB) {
		alerts = append(alerts, fmt.Sprintf("Container %s memory usage %.1fMB exceeds threshold %dMB", 
			item.Name, item.Memory, config.MaxMemMB))
	}

	// 如果有任何告警，发送通知
	if len(alerts) > 0 {
		for _, alertMsg := range alerts {
			SendAlert("Resource Alert", alertMsg)
		}
	}
}

// 发送告警通知
func SendAlert(title, message string) {
	log.Printf("🔔 Alert: %s - %s", title, message)
	
	// 发送告警到 webhook（如果配置了）
	if config.AlertWebhook != "" {
		sendToWebhook(title, message)
	}
	
	// 发送邮件告警（如果配置了）
	if config.AlertEmail != "" {
		sendEmailAlert(title, message)
	}
}

// 发送到 Webhook
func sendToWebhook(title, message string) {
	payload := map[string]string{
		"title":   title,
		"message": message,
		"time":    time.Now().Format("2006-01-02 15:04:05"),
	}
	
	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		log.Printf("Error marshaling webhook payload: %v", err)
		return
	}
	
	resp, err := http.Post(
		config.AlertWebhook,
		"application/json",
		bytes.NewBuffer(jsonPayload),
	)
	
	if err != nil {
		log.Printf("Error sending webhook: %v", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		log.Printf("Webhook sent successfully: %s - %s", title, message)
	} else {
		log.Printf("Webhook failed with status: %d", resp.StatusCode)
	}
}

// 发送邮件告警（简化实现，实际项目中需要集成邮件服务）
func sendEmailAlert(title, message string) {
	// 注意：实际项目中需要实现真正的邮件发送功能
	// 这里只是记录日志
	log.Printf("Would send email to %s: %s - %s", config.AlertEmail, title, message)
}