package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

type ServiceMonitor struct {
	Nginx   NginxStatus   `json:"nginx"`
	NSQ     NSQStatus     `json:"nsq"`
	Redis   RedisStatus   `json:"redis"`
	Elastic ElasticStatus `json:"elastic"`
	MySQL   MySQLStatus   `json:"mysql"`
}

type NginxStatus struct {
	Active  int  `json:"active"`
	Waiting int  `json:"waiting"`
	Reading int  `json:"reading"`
	Writing int  `json:"writing"`
	Online  bool `json:"online"`
	Error   string `json:"error,omitempty"`
}

type NSQStatus struct {
	Online      bool         `json:"online"`
	Topics      []NSQTopic   `json:"topics"`
	Channels    []NSQChannel `json:"channels"`
	HealthCheck NSQHealth    `json:"health_check"`
	Lookupd     NSQLookupd   `json:"lookupd"`
	Version     string       `json:"version"`
	Hostname    string       `json:"hostname"`
	Error       string       `json:"error,omitempty"`
}

type NSQTopic struct {
	Name       string       `json:"name"`
	Depth      int64        `json:"depth"`
	ChannelNum int          `json:"channel_num"`
	Channels   []NSQChannel `json:"channels"`
}

type NSQChannel struct {
	Name         string `json:"name"`
	Depth        int64  `json:"depth"`
	InFlight     int64  `json:"in_flight_count"`
	Deferred     int64  `json:"deferred_count"`
	MessageCount int64  `json:"message_count"`
	ClientCount  int    `json:"client_count"`
}

type NSQHealth struct {
	OK      bool   `json:"ok"`
	Version string `json:"version"`
}

type NSQLookupd struct {
	Online bool     `json:"online"`
	Nodes  []string `json:"nodes"`
	Count  int      `json:"count"`
	Error  string   `json:"error,omitempty"`
}

type RedisStatus struct {
	Online bool   `json:"online"`
	Error  string `json:"error,omitempty"`
}

type ElasticStatus struct {
	Online bool   `json:"online"`
	Status string `json:"status"`
	Nodes  int    `json:"nodes"`
	Error  string `json:"error,omitempty"`
}

type MySQLStatus struct {
	Online bool   `json:"online"`
	Error  string `json:"error,omitempty"`
}

var (
	ServiceData ServiceMonitor
	serviceMutex sync.RWMutex
)

func GetNginx() NginxStatus {
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://nginx:80/nginx_status")
	if err != nil {
		return NginxStatus{Online: false, Error: err.Error()}
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return NginxStatus{Online: false, Error: err.Error()}
	}
	
	lines := strings.Split(string(body), "\n")
	var s NginxStatus
	if len(lines) >= 4 {
		// Active connections: 291
		if strings.Contains(lines[0], "Active connections:") {
			parts := strings.Fields(lines[0])
			if len(parts) >= 3 {
				s.Active, _ = strconv.Atoi(parts[2])
			}
		}
		
		// Reading: 6 Writing: 179 Waiting: 106
		if len(lines) > 2 && strings.Contains(lines[2], "Reading:") {
			parts := strings.Fields(lines[2])
			for i, part := range parts {
				if part == "Reading:" && i+1 < len(parts) {
					s.Reading, _ = strconv.Atoi(strings.TrimSuffix(parts[i+1], ","))
				} else if part == "Writing:" && i+1 < len(parts) {
					s.Writing, _ = strconv.Atoi(strings.TrimSuffix(parts[i+1], ","))
				} else if part == "Waiting:" && i+1 < len(parts) {
					s.Waiting, _ = strconv.Atoi(parts[i+1])
				}
			}
		}
	}
	s.Online = true
	return s
}

func GetNSQ() NSQStatus {
	status := NSQStatus{}

	// 获取 nsqd 状态
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://nsqd:4151/stats?format=json")
	if err != nil {
		return NSQStatus{Online: false, Error: err.Error()}
	}
	defer resp.Body.Close()

	var res struct {
		Version  string `json:"version"`
		Hostname string `json:"hostname"`
		Topics   []struct {
			TopicName  string `json:"topic_name"`
			Depth      int64  `json:"depth"`
			ChannelNum int    `json:"channel_pcounts"`
			Channels   []struct {
				ChannelName   string `json:"channel_name"`
				Depth         int64  `json:"depth"`
				InFlightCount int64  `json:"in_flight_count"`
				DeferredCount int64  `json:"deferred_count"`
				MessageCount  int64  `json:"message_count"`
				ClientCount   int    `json:"client_count"`
			} `json:"channels"`
		} `json:"topics"`
	}
	err = json.NewDecoder(resp.Body).Decode(&res)
	if err != nil {
		return NSQStatus{Online: false, Error: err.Error()}
	}

	// 处理 topic 和 channel 数据
	var topics []NSQTopic
	for _, t := range res.Topics {
		var channels []NSQChannel
		for _, ch := range t.Channels {
			channel := NSQChannel{
				Name:         ch.ChannelName,
				Depth:        ch.Depth,
				InFlight:     ch.InFlightCount,
				Deferred:     ch.DeferredCount,
				MessageCount: ch.MessageCount,
				ClientCount:  ch.ClientCount,
			}
			channels = append(channels, channel)

			// 检查通道深度告警
			if ch.Depth > config.MaxNSQDepth {
				SendAlert("NSQ Channel Alert", "Channel: "+t.TopicName+"/"+ch.ChannelName+" has depth "+strconv.FormatInt(ch.Depth, 10))
			}
		}

		topic := NSQTopic{
			Name:       t.TopicName,
			Depth:      t.Depth,
			ChannelNum: t.ChannelNum,
			Channels:   channels,
		}
		topics = append(topics, topic)

		// 检查主题深度告警
		if t.Depth > config.MaxNSQDepth {
			SendAlert("NSQ Topic Alert", "Topic: "+t.TopicName+" has depth "+strconv.FormatInt(t.Depth, 10))
		}
	}

	// 获取健康检查状态
	healthResp, healthErr := client.Get("http://nsqd:4151/ping")
	if healthErr == nil {
		defer healthResp.Body.Close()
		healthBody, _ := io.ReadAll(healthResp.Body)
		healthStatus := strings.TrimSpace(string(healthBody))
		status.HealthCheck = NSQHealth{
			OK:      healthStatus == "OK",
			Version: res.Version,
		}
	} else {
		status.HealthCheck = NSQHealth{OK: false, Version: ""}
	}

	// 获取 lookupd 集群状态
	lookupdStatus := getNSQLookupdStatus(client)

	status.Online = true
	status.Topics = topics
	status.Lookupd = lookupdStatus
	status.Version = res.Version
	status.Hostname = res.Hostname

	return status
}

func getNSQLookupdStatus(client *http.Client) NSQLookupd {
	// 尝试连接 lookupd 服务
	resp, err := client.Get("http://nsqlookupd:4161/nodes")
	if err != nil {
		return NSQLookupd{Online: false, Error: err.Error()}
	}
	defer resp.Body.Close()

	var nodesRes struct {
		Producers []struct {
			RemoteAddress    string   `json:"remote_address"`
			Hostname         string   `json:"hostname"`
			BroadcastAddress string   `json:"broadcast_address"`
			TCPPort          int      `json:"tcp_port"`
			HTTPPort         int      `json:"http_port"`
			Version          string   `json:"version"`
			Topics           []string `json:"topics"`
		} `json:"producers"`
	}

	err = json.NewDecoder(resp.Body).Decode(&nodesRes)
	if err != nil {
		return NSQLookupd{Online: false, Error: err.Error()}
	}

	var nodes []string
	for _, producer := range nodesRes.Producers {
		nodeAddr := producer.BroadcastAddress + ":" + strconv.Itoa(producer.TCPPort)
		nodes = append(nodes, nodeAddr)
	}

	return NSQLookupd{
		Online: true,
		Nodes:  nodes,
		Count:  len(nodes),
	}
}

func GetRedis() RedisStatus {
	conn, err := net.DialTimeout("tcp", "redis:6379", 2*time.Second)
	if err != nil {
		return RedisStatus{Online: false, Error: err.Error()}
	}
	defer conn.Close()
	
	// 发送 PING 命令
	_, err = conn.Write([]byte("*1\r\n$4\r\nPING\r\n"))
	if err != nil {
		return RedisStatus{Online: false, Error: err.Error()}
	}
	
	buf := make([]byte, 1024)
	n, err := conn.Read(buf)
	if err != nil {
		return RedisStatus{Online: false, Error: err.Error()}
	}
	
	response := string(buf[:n])
	if strings.Contains(response, "+PONG") || strings.Contains(response, "$4\r\nPONG") {
		return RedisStatus{Online: true}
	}
	return RedisStatus{Online: false, Error: "Redis did not respond with PONG"}
}

func GetES() ElasticStatus {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://elasticsearch:9200/_cluster/health")
	if err != nil {
		return ElasticStatus{Online: false, Error: err.Error()}
	}
	defer resp.Body.Close()
	
	var res struct {
		Status string `json:"status"`
		Nodes  int    `json:"number_of_nodes"`
	}
	err = json.NewDecoder(resp.Body).Decode(&res)
	if err != nil {
		return ElasticStatus{Online: false, Error: err.Error()}
	}
	
	return ElasticStatus{
		Online: true,
		Status: res.Status,
		Nodes:  res.Nodes,
	}
}

func GetMySQL() MySQLStatus {
	// 简单的 MySQL 连接测试
	// 实际项目中可能需要引入 MySQL 驱动
	// 这里我们尝试连接 MySQL 默认端口
	conn, err := net.DialTimeout("tcp", "mysql:3306", 2*time.Second)
	if err != nil {
		return MySQLStatus{Online: false, Error: err.Error()}
	}
	defer conn.Close()
	
	// MySQL 握手协议比较复杂，这里只是简单测试连接
	// 实际生产环境中应使用专门的驱动进行连接测试
	return MySQLStatus{Online: true}
}

func MonitorServices(ctx context.Context) {
	ticker := time.NewTicker(time.Duration(config.CheckInterval) * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			log.Println("Service monitor stopped")
			return
		case <-ticker.C:
			newData := ServiceMonitor{}
			
			newData.Nginx = GetNginx()
			newData.NSQ = GetNSQ()
			newData.Redis = GetRedis()
			newData.Elastic = GetES()
			newData.MySQL = GetMySQL()
			
			serviceMutex.Lock()
			ServiceData = newData
			serviceMutex.Unlock()
		}
	}
}