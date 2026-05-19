#!/bin/bash




# 创建默认的index.html
cat > /data/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to nginx!</title>
    <style>
        body { width: 35em; margin: 0 auto; font-family: Tahoma, Verdana, Arial, sans-serif; }
    </style>
</head>
<body>
    <h1>Welcome to nginx!</h1>
    <p>If you see this page, the nginx web server is successfully installed and working.</p>
</body>
</html>
EOF

# 设置目录权限
chmod -R 755 /data/nginx
chown -R 101:101 /data/nginx  # 匹配nginx容器内的用户ID
