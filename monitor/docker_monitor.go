package main

import (
	"context"
	"encoding/json"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/moby/moby/api/types"
	"github.com/moby/moby/api/types/container"
	"github.com/moby/moby/client"
)

type ContainerStatus struct {
	Name      string  `json:"name"`
	ID        string  `json:"id"`
	State     string  `json:"state"`
	CPU       float64 `json:"cpu"`
	Memory    float64 `json:"mem"`
	Status    string  `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

var (
	MonitorData []ContainerStatus
	dockerCli   *client.Client
	mutex       sync.RWMutex
)

func initDocker() {
	var err error
	dockerCli, err = client.NewClientWithOpts(
		client.FromEnv,
		client.WithAPIVersionNegotiation(),
	)
	if err != nil {
		log.Fatal("Failed to init docker client:", err)
	}
}

func getContainerStats(id string) (float64, float64) {
	statsResp, err := dockerCli.ContainerStats(context.Background(), id, false)
	if err != nil {
		return 0, 0
	}
	defer statsResp.Body.Close()

	var stats types.StatsJSON
	if err := json.NewDecoder(statsResp.Body).Decode(&stats); err != nil {
		return 0, 0
	}

	cpuDelta := float64(stats.CPUStats.CPUUsage.TotalUsage - stats.PreCPUStats.CPUUsage.TotalUsage)
	systemDelta := float64(stats.CPUStats.SystemUsage - stats.PreCPUStats.SystemUsage)
	cpuPercent := 0.0
	if systemDelta > 0 {
		cpuPercent = (cpuDelta / systemDelta) * 100.0
	}

	memMB := float64(stats.MemoryStats.Usage) / 1024 / 1024
	return cpuPercent, memMB
}

func MonitorDockerContainers() {
	initDocker()
	ticker := time.NewTicker(time.Duration(config.DockerCheckInterval) * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		containers, err := dockerCli.ContainerList(context.Background(), container.ListOptions{All: true})
		if err != nil {
			log.Println("List containers error:", err)
			continue
		}

		var list []ContainerStatus
		for _, c := range containers {
			name := strings.TrimPrefix(c.Names[0], "/")
			cpu, mem := getContainerStats(c.ID)
			
			containerStatus := ContainerStatus{
				Name:   name,
				ID:     c.ID[:12],
				State:  c.State,
				CPU:    cpu,
				Memory: mem,
				Status: c.Status,
				CreatedAt: time.Unix(c.Created, 0),
			}
			
			list = append(list, containerStatus)
			
			// 检查容器状态和资源使用情况
			CheckAlert(containerStatus)
		}
		
		// 安全更新全局数据
		mutex.Lock()
		MonitorData = list
		mutex.Unlock()
	}
}