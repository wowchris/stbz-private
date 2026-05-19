#!/bin/bash

# 判断用户，非 root 用户无法执行安装
if [ $USER != "root" ]
then
    echo "ERROR: Unable to perform installation as non-root user."
    exit
fi

# 国内镜像
curl -L https://get.daocloud.io/docker/compose/releases/download/1.29.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose    || ceho "Download docker-compose fails, check the network is normal"

chmod +x /usr/local/bin/docker-compose  && ln -sf /usr/local/bin/docker-compose  /usr/bin/docker-compose

docker-compose --version
dockercompose_install_success=`docker-compose --version|grep -o version`

#安装验证
if [ $"$dockercompose_install_success" ]
then
	echo "docker-compose install  successd "
else
	echo "ERROR: docker-compose install failed."
	exit

fi



