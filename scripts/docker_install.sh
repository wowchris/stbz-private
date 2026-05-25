#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${BASE_DIR}/main.sh"
Get_System_Name

if [ "${USER:-}" != "root" ]; then
    echo "ERROR: Unable to perform installation as non-root user."
    exit 1
fi

configure_docker_daemon() {
    mkdir -p /etc/docker
    if [ ! -f /etc/docker/daemon.json ]; then
        cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": ["https://registry.cn-hangzhou.aliyuncs.com"]
}
EOF
    fi
    systemctl daemon-reload || true
    sysctl -w net.ipv4.ip_forward=1 || true
}

install_docker_yum() {
    if command -v firewall-cmd >/dev/null 2>&1; then
        systemctl stop firewalld || true
        systemctl disable firewalld || true
    fi
    if command -v setenforce >/dev/null 2>&1; then
        setenforce 0 || true
    fi

    yum -y install yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum makecache fast
    yum -y install docker-ce docker-ce-cli containerd.io
    yum -y install bash-completion || true
    source /usr/share/bash-completion/bash_completion || true
}

install_docker_apt() {
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release software-properties-common
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
}

case "${PM:-yum}" in
    yum)
        install_docker_yum
        ;;
    apt)
        install_docker_apt
        ;;
    *)
        echo "Unsupported package manager: ${PM:-unknown}"
        exit 1
        ;;
esac

configure_docker_daemon
systemctl enable docker
systemctl restart docker

if ! docker --version >/dev/null 2>&1; then
    echo "ERROR: docker install failed."
    exit 1
fi

echo "docker install success"
