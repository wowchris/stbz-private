package main

import (
	"context"
	"html/template"
	"net/http"
	"sync"
	"time"
)

type PageData struct {
	Docker  []ContainerStatus
	Service ServiceMonitor
	Timestamp time.Time
}

var (
	indexTpl = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>服务监控面板</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box;font-family:system-ui}
        body{background:#f1f5f9;padding:20px}
        .header{background:white;border-radius:12px;padding:20px;box-shadow:0 1px 3px #0001;margin-bottom:20px;text-align:center}
        .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px;margin-bottom:20px}
        .card{background:white;border-radius:12px;padding:18px;box-shadow:0 1px 3px #0001}
        .status{display:inline-block;padding:4px 8px;border-radius:6px;font-size:12px}
        .ok{background:#dcfce7;color:#166534}
        .no{background:#fee2e2;color:#991b1b}
        .warn{background:#fef3c7;color:#92400e}
        table{width:100%;border-collapse:collapse;margin-top:10px}
        th,td{padding:10px;text-align:left;border-bottom:1px solid #e2e8f0}
        .refresh-info{text-align:right;font-size:12px;color:#64748b;margin-top:10px}
        .nsq-topic{margin: 10px 0; padding: 10px; border-left: 4px solid #3b82f6; background-color: #eff6ff;}
        .nsq-channel{margin: 5px 0; padding: 5px; border-left: 2px solid #93c5fd; background-color: #f0f9ff;}
    </style>
</head>
<body>
    <div class="header">
        <h2>服务监控面板</h2>
        <p>实时监控 Docker 容器和服务状态</p>
    </div>
    
    <h3>服务状态</h3>
    <div class="grid">
        <div class="card">
            <h4>Nginx</h4>
            <span class="{{if .Service.Nginx.Online}}ok{{else}}no{{end}}">
                {{if .Service.Nginx.Online}}正常{{else}}异常{{end}}
            </span>
            {{if .Service.Nginx.Online}}
            <p>活跃连接: {{.Service.Nginx.Active}}</p>
            <p>等待连接: {{.Service.Nginx.Waiting}}</p>
            {{end}}
        </div>
        <div class="card">
            <h4>Redis</h4>
            <span class="{{if .Service.Redis.Online}}ok{{else}}no{{end}}">
                {{if .Service.Redis.Online}}正常{{else}}异常{{end}}
            </span>
        </div>
        <div class="card">
            <h4>NSQ</h4>
            <span class="{{if .Service.NSQ.Online}}ok{{else}}no{{end}}">
                {{if .Service.NSQ.Online}}正常{{else}}异常{{end}}
            </span>
            {{if .Service.NSQ.Online}}
            <p>版本: {{.Service.NSQ.Version}}</p>
            <p>主机名: {{.Service.NSQ.Hostname}}</p>
            <p>主题数量: {{len .Service.NSQ.Topics}}</p>
            <p>健康检查: {{if .Service.NSQ.HealthCheck.OK}}OK{{else}}FAIL{{end}}</p>
            {{end}}
        </div>
        <div class="card">
            <h4>NSQ Lookupd</h4>
            <span class="{{if .Service.NSQ.Lookupd.Online}}ok{{else}}no{{end}}">
                {{if .Service.NSQ.Lookupd.Online}}正常{{else}}异常{{end}}
            </span>
            {{if .Service.NSQ.Lookupd.Online}}
            <p>节点数: {{.Service.NSQ.Lookupd.Count}}</p>
            {{end}}
        </div>
        <div class="card">
            <h4>Elasticsearch</h4>
            <span class="{{if eq .Service.Elastic.Status "green"}}ok{{else if eq .Service.Elastic.Status "yellow"}}warn{{else}}no{{end}}">
                {{.Service.Elastic.Status}}
            </span>
            {{if .Service.Elastic.Online}}
            <p>节点数: {{.Service.Elastic.Nodes}}</p>
            {{end}}
        </div>
        <div class="card">
            <h4>MySQL</h4>
            <span class="{{if .Service.MySQL.Online}}ok{{else}}no{{end}}">
                {{if .Service.MySQL.Online}}正常{{else}}异常{{end}}
            </span>
        </div>
    </div>
    
    {{if .Service.NSQ.Online}}
    <h3>NSQ 主题详情</h3>
    <div class="card">
        {{range .Service.NSQ.Topics}}
        <div class="nsq-topic">
            <strong>{{.Name}}</strong> | 深度: {{.Depth}} | 频道数: {{.ChannelNum}}
            {{if .Channels}}
            <div style="margin-top: 8px;">
                <h5>频道:</h5>
                {{range .Channels}}
                <div class="nsq-channel">
                    {{.Name}} | 深度: {{.Depth}} | 飞行中: {{.InFlight}} | 延迟: {{.Deferred}} | 消息数: {{.MessageCount}} | 客户端: {{.ClientCount}}
                </div>
                {{end}}
            </div>
            {{end}}
        </div>
        {{end}}
    </div>
    {{end}}
    
    {{if .Service.NSQ.Lookupd.Online}}
    <h3>NSQ Lookupd 节点</h3>
    <div class="card">
        <ul>
        {{range .Service.NSQ.Lookupd.Nodes}}
            <li>{{.}}</li>
        {{end}}
        </ul>
    </div>
    {{end}}
    
    <h3>容器监控</h3>
    <div class="card">
        <table>
            <thead>
                <tr>
                    <th>名称</th>
                    <th>状态</th>
                    <th>CPU</th>
                    <th>内存</th>
                    <th>状态详情</th>
                </tr>
            </thead>
            <tbody>
                {{range .Docker}}
                <tr>
                    <td>{{.Name}}</td>
                    <td>{{.State}}</td>
                    <td>{{printf "%.1f%%" .CPU}}</td>
                    <td>{{printf "%.1f MB" .Memory}}</td>
                    <td>{{.Status}}</td>
                </tr>
                {{end}}
            </tbody>
        </table>
        <div class="refresh-info">最后刷新: {{.Timestamp.Format "2006-01-02 15:04:05"}}</div>
    </div>
    
    <script>
        setTimeout(() => location.reload(), 5000);
    </script>
</body>
</html>
`

	apiTpl = `{"docker": {{.Docker}}, "service": {{.Service}}, "timestamp": "{{.Timestamp.Format "2006-01-02T15:04:05Z07:00"}}"}`
	
	mutex sync.RWMutex
)

func auth(w http.ResponseWriter, r *http.Request) bool {
	user, pass, ok := r.BasicAuth()
	if !ok || user != config.WebUsername || pass != config.WebPassword {
		w.Header().Set("WWW-Authenticate", `Basic realm="monitor"`)
		w.WriteHeader(401)
		return false
	}
	return true
}

func StartWebServer() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if !auth(w, r) {
			return
		}
		
		// 读取数据时加锁
		mutex.RLock()
		data := PageData{
			Docker:  MonitorData,
			Service: ServiceData,
			Timestamp: time.Now(),
		}
		mutex.RUnlock()
		
		tpl, _ := template.New("index").Parse(indexTpl)
		tpl.Execute(w, data)
	})
	
	// API 接口返回 JSON 格式数据
	http.HandleFunc("/api/status", func(w http.ResponseWriter, r *http.Request) {
		if !auth(w, r) {
			return
		}
		
		w.Header().Set("Content-Type", "application/json")
		
		// 读取数据时加锁
		mutex.RLock()
		data := PageData{
			Docker:  MonitorData,
			Service: ServiceData,
			Timestamp: time.Now(),
		}
		mutex.RUnlock()
		
		tpl, _ := template.New("api").Parse(apiTpl)
		tpl.Execute(w, data)
	})

	http.ListenAndServe(":9999", nil)
}