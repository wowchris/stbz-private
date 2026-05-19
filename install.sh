#!/usr/bin/env bash

set -o pipefail

# define youre domain name 
# example :  google.com
export DOMAINNAME=''
export HOST_IP=$(hostname -I |awk '{print $1}')

# DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DATA=/data
MYSQL_USER=''
MYSQL_PWD=''
MYSQL_ADDR=''
NGINX_DIR=/data/nginx
NSQ_DIR=/data/nsq
REDIS_DIR=/data/redis
ELK_DIR=/data/elk
PRIVATE_DIR=/data/project/backend
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"


if [ -z "$DOMAINNAME"  ] && [ -z "$MYSQL_USER"  ] && [ -z "$MYSQL_PWD"  ] && [ -z "$MYSQL_ADDR" ] ;then
    exit 1
fi

# creat docker network <192.168.210.0>
yum update -y
yum install lsof telnet htop -y

cd "${PROJECT_DIR}" || exit 1
chmod +x $(find ./ -name *.sh)


. "${PROJECT_DIR}/scripts/common.sh"

function prepare_install() {
	for i in docker docker-compose; do
		command -v $i &>/dev/null || exit 1
	done
}


function prepare_dir() {
	cd ${PROJECT_DIR}
 	echo -e "\033[32m 准备目录结构 \033[0m" 
	if [[ ! -d ${BASE_DATA} ]]; then
		mkdir -p "${BASE_DATA}"
	fi
	for i in nginx elk mysql redis nsq;do
		\cp -rf $i  /data
	done
	echo $PWD
		
}



function install_nginx() {
	netstat -nlpt | grep nginx &> /dev/null
	if [ $? -eq 0 ];then
		echo "nginx已经启动！"
		return 
	else
	    echo "nginx没有运行！"
	    cd ${NGINX_DIR}
	    echo "config Domain Name for conf file"
	    sed -i "s/domain_name/${DOMAINNAME}/g" $(grep -rl domain_name)
	    # 设置目录权限
		chmod -R 755 /data/nginx
		chown -R 101:101 /data/nginx 

		docker-compose up -d 
	fi

   
}


function deploy_private() {
	mkdir -p /data/project/backend 
        cd ${PROJECT_DIR}
        echo " project file  deploy "

        \cp  -rf project  /data/

        echo "config directory for nginx vhost"
        /usr/local/nginx/sbin/nginx -s reload
        if [ $? -eq 0 ];then
        echo 'nginx hot restart successed!'
                else
        echo 'nginx hot restart fails'
                exit
        fi

}


function docker_mysql() {
	cd ${MYSQL_DIR} && chmod  755 mysqldata  -R
	#ARGS_MYSQL=`docker ps --format "{{.Names}}" |grep mysql`
	ARGS_MYSQL=`/usr/sbin/lsof -i :8081|grep -v "PID" | awk '{print $2}'`
	if [ "$ARGS_MYSQL" != ""  ]
	then
	    echo "mysql port is exists"
	    exit 1
	fi
	
	
	if [[ -f "Dockerfile" ]]; then
	    docker build -t mysql:5.6 .
	else
	    echo "Dockerfile  not exist"
	    exit 1
	fi
	
	if [[ -f "docker-compose.yml" ]]; then
	    docker-compose up  -d
	else
	    echo "compose file not exist"
	    exit 1
	fi	
}


function docker_nsq() {
	cd ${NSQ_DIR}
	echo  "nsq MQ"
	docker-compose up -d && docker-compose restart
}



function docker_redis() {
	cd ${REDIS_DIR} && chmod  755 data -R
	ARGS_REDIS=`docker ps --format "{{.Names}}" |grep redis`
	if [ -n $ARGS_REDIS  ]
	then
	    echo "stop and delete current container"
	    docker stop $ARGS_REDIS && docker rm $ARGS_REDIS
	fi
	
	
	if [[ -f "Dockerfile" ]]; then
	    docker build -t redis:5.0.12 .
	else
	    echo "Dockerfile  not exist"
	    exit 1
	fi
	
	if [[ -f "docker-compose.yml" ]]; then
	    docker-compose up  -d
	else
	    echo "compose file not exist"
	    exit 1
	fi	
}



function docker_elk() {

	cd ${ELK_DIR}
	sed -i "s/HOST_IP/${HOST_IP}/g"  `grep -rl "HOST_IP" ./* `
	docker network  create  -d bridge --subnet=192.168.210.0/24 --gateway=192.168.210.1   staticnet

	docker-compose build  
        docker-compose -f elk.yml up -d
	echo "等待ES端口启动..."
	sleep 10
	
	port=`lsof -i:9200 | wc -l`
	if [ "$port" -eq "0" ];then
	    echo "es prot:9200 start false"
	    exit 1
	else
	    echo "es prot:9200 start success  and initialize elk"
	    chmod +x  ${ELK_DIR}/logstash/init.sh 
	    source ./time
	    echo "" | telnet ${HOST_IP} 9200  |grep is |awk '{print $2}' >tmp.txt
	    if cat tmp.txt |grep "character" > /dev/null; then
	        /bin/bash ${ELK_DIR}/logstash/init.sh 
		docker-compose up -d
	    else
		echo 'elk 初始化失败!'
	    fi  	
	fi
	
}

function docker_private() {
	cd ${PRIVATE_DIR}
        sed -i "s/HOST_IP/${HOST_IP}/g"  `grep -rl "HOST_IP" ./* `

	docker-compose up -d  && docker-compose restart
	if [ $? -eq 0 ]; then
            echo " private-docker start success "
        else
            echo " private-docker start false "
            exit 1 
        fi



}





function main() {

  prepare_install
  prepare_dir
  install_nginx
  #docker_mysql
  docker_nsq
  docker_redis
  docker_elk
  deploy_private
  docker_private
}


if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi
