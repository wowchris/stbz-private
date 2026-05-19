#!/bin/bash

# 判断用户，非 root 用户无法执行安装
if [ $USER != "root" ]
then
    echo "ERROR: Unable to perform installation as non-root user."
    exit
fi


#环境配置
systemctl stop firewalld && systemctl disable firewalld
setenforce 0

#安装依赖包
yum -y install yum-utils device-mapper-persistemt-data lvm2

#设置阿里云镜像源
cd /etc/yum.repos.d/
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

#安装 docker-ce 
yum -y install docker-ce
#curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

yum install -y bash-completion && source /usr/share/bash-completion/bash_completion

#配置阿里云镜像加速（尽量使用自己的）
#地址 https://help.aliyun.com/document_detail/60750.html
mkdir -p /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://n27609rs.mirror.aliyuncs.com"]
}
EOF
 systemctl daemon-reload

#网络优化
cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
EOF

sysctl -p
systemctl restart network
systemctl enable docker && systemctl restart docker

# subnet for elk
docker network  create  -d bridge --subnet=192.168.210.0/24 --gateway=192.168.210.1 -o parent=eth0 staticnet


# 安装验证
docker_install_success=`docker -v|grep -o version`

if [ $"$docker_install_success" ]
then
	echo "docker install  successd "
else
	echo "ERROR: docker install failed."
	exit

fi


