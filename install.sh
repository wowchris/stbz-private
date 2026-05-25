#!/usr/bin/env bash

# Unified installation script for the Private project
# Combines the best features of the original install.sh and install_optimized.sh
# Supports CentOS, Alibaba Cloud Linux, and Ubuntu systems

set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Private Project Unified Installation${NC}"

# project base
BASE_DATA=/data
NGINX_DIR=/data/nginx
NSQ_DIR=/data/nsq
REDIS_DIR=/data/redis
ELK_DIR=/data/elk
PRIVATE_DIR=/data/project/backend
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ "$(uname -s)" != "Linux" ]; then
	echo -e "${RED}ERROR: install.sh only supports Linux systems.${NC}" >&2
	exit 1
fi

# Load .env if present
ENV_FILE="${PROJECT_DIR}/.env"
if [ -f "${ENV_FILE}" ]; then
	set -a
	# shellcheck disable=SC1090
	. "${ENV_FILE}"
	set +a
fi

# directory variables can be overridden in .env
BASE_DATA="${MOUNTED_SHARED_DIRECTORY:-/data}"
NGINX_DIR="${NGINX_DIR:-${BASE_DATA}/nginx}"
MYSQL_DIR="${MYSQL_DIR:-${BASE_DATA}/mysql}"
REDIS_DIR="${REDIS_DIR:-${BASE_DATA}/redis}"
ELK_DIR="${ELK_DIR:-${BASE_DATA}/elk}"
PRO_DIR="${PRO_DIR:-${BASE_DATA}/project}"
PRIVATE_DIR="${PRIVATE_DIR:-${PRO_DIR}/backend}"

# determine HOST_IP robustly
if [ -n "${HOST_IP:-}" ]; then
	:
elif command -v hostname >/dev/null 2>&1 && hostname -I >/dev/null 2>&1; then
	HOST_IP=$(hostname -I | awk '{print $1}')
elif command -v ip >/dev/null 2>&1; then
	HOST_IP=$(ip -4 addr show scope global | grep -oP "(?<=inet\s)\d+(\.\d+){3}" | head -n1 || echo "127.0.0.1")
else
	HOST_IP=127.0.0.1
fi

# Basic required-variable check - combining both scripts
required_vars=(DOMAINNAME DB_PASSWORD REDIS_PASSWORD ELASTIC_PASSWORD)
missing=()
for v in "${required_vars[@]}"; do
	if [ -z "${!v:-}" ]; then
		missing+=("$v")
	fi
done
if [ ${#missing[@]} -gt 0 ]; then
	echo -e "${YELLOW}Warning: missing required env vars in .env file: ${missing[*]}${NC}" >&2
	echo -e "${YELLOW}Please check your .env file contains all required variables.${NC}" >&2
fi

cd "${PROJECT_DIR}" || exit 1

# Make shell scripts executable
if command -v find >/dev/null 2>&1 && command -v xargs >/dev/null 2>&1; then
	find . -type f -name '*.sh' -print0 | xargs -0 chmod +x || true
else
	chmod +x ./scripts/*.sh || true
fi

# Detect operating system and package manager
. "${PROJECT_DIR}/scripts/main.sh"
Get_System_Name
if [ -n "${DISTRO:-}" ]; then
	echo -e "${GREEN}Detected OS: ${DISTRO}, package manager: ${PM}${NC}"
fi

# Check if the detected OS is supported
if [ "${DISTRO:-}" != "CentOS" ] && [ "${DISTRO:-}" != "Alibaba" ] && [ "${DISTRO:-}" != "Ubuntu" ] && [ "${DISTRO:-}" != "Aliyun" ]; then
    echo -e "${YELLOW}Warning: This system (${DISTRO:-unknown}) may not be officially supported.${NC}" >&2
    echo -e "${YELLOW}Supported systems: CentOS, Alibaba Cloud Linux, Ubuntu${NC}" >&2
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Installation cancelled.${NC}" >&2
        exit 1
    fi
fi

. "${PROJECT_DIR}/scripts/common.sh"

# Verify prerequisites
function verify_prerequisites() {
    echo -e "${GREEN}Verifying prerequisites...${NC}"
    
    # Check if docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}Docker is not installed. Please install Docker first.${NC}" >&2
        exit 1
    fi
    
    # Check if docker-compose is installed
    if ! command -v docker-compose >/dev/null 2>&1; then
        echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}" >&2
        exit 1
    fi
    
    # Check Docker version
    DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [[ $(printf '%s\n' "19.03.0" "$DOCKER_VERSION" | sort -V | head -n1) = "19.03.0" ]]; then
        echo -e "${GREEN}Docker version $DOCKER_VERSION is compatible${NC}"
    else
        echo -e "${YELLOW}Warning: Docker version $DOCKER_VERSION might be too old. Recommended: 19.03.0 or newer${NC}"
    fi
    
    echo -e "${GREEN}Prerequisites verified successfully${NC}"
}

function prepare_install() {
	if [ "${PM:-}" != "yum" ] && [ "${PM:-}" != "apt" ]; then
		echo -e "${RED}Unsupported distribution for auto deployment: ${DISTRO:-unknown}${NC}" >&2
		exit 1
	fi

	if ! command -v docker >/dev/null 2>&1; then
		echo -e "${GREEN}Docker not found, installing...${NC}"
		. "${PROJECT_DIR}/scripts/docker_install.sh"
	fi
	if ! command -v docker-compose >/dev/null 2>&1; then
		echo -e "${GREEN}Docker Compose not found, installing...${NC}"
		. "${PROJECT_DIR}/scripts/docker-compose_install.sh"
	fi
	for i in docker docker-compose; do
		command -v "$i" &>/dev/null || exit 1
	done
}

function prepare_dir() {
	cd "${PROJECT_DIR}" || return 1
 	echo -e "${GREEN} 准备目录结构 ${NC}" 
 	if [[ ! -d ${BASE_DATA} ]]; then
 		mkdir -p "${BASE_DATA}"
 	fi
 	for i in nginx elk mysql redis nsq; do
 		if [[ -d "$i" ]]; then
 			if command -v rsync >/dev/null 2>&1; then
 				rsync -a "$i" "${BASE_DATA}/$i/"
 			else
 				cp -a "$i" "${BASE_DATA}/$i/"
 			fi
 		fi
 	done

 	# unify service environment files from root .env
 	if [[ -f "${PROJECT_DIR}/.env" ]]; then
 		for sub in mysql redis elk project/backend; do
 			if [[ -d "${PROJECT_DIR}/${sub}" ]]; then
 				cp -f "${PROJECT_DIR}/.env" "${PROJECT_DIR}/${sub}/.env"
 			fi
 		done
 	fi
 	echo "$PWD"
}

function install_nginx() {
	if netstat -nlpt | grep nginx &> /dev/null; then
		echo -e "${YELLOW}nginx already running!${NC}"
		return
	fi

	echo -e "${GREEN}Installing nginx...${NC}"
	cd "${NGINX_DIR}" || return 1
	echo -e "${GREEN}Configuring Domain Name for conf file${NC}"
	if [ -n "${DOMAINNAME}" ]; then
		if grep -R --line-number --quiet 'domain_name' .; then
			grep -rlZ 'domain_name' . | xargs -0 sed -i "s/domain_name/${DOMAINNAME}/g" || true
		fi
	fi
	# 设置目录权限
	chmod -R 755 "${NGINX_DIR}" || true
	chown -R 101:101 "${NGINX_DIR}" || true

	# validate compose before up
	if docker-compose config >/dev/null 2>&1; then
		docker-compose up -d
		echo -e "${GREEN}Nginx started successfully${NC}"
	else
		echo -e "${RED}docker-compose config invalid for nginx${NC}" >&2
		return 1
	fi
}

function deploy_private() {
	mkdir -p "${PRO_DIR:-/data/project}"/backend
	cd "${PROJECT_DIR}" || return 1
	echo -e "${GREEN}Deploying project files${NC}"

	cp -a project "${BASE_DATA}/project/"

	if command -v /usr/local/nginx/sbin/nginx >/dev/null 2>&1; then
		/usr/local/nginx/sbin/nginx -s reload
		if [ $? -eq 0 ]; then
			echo -e "${GREEN}nginx hot restart succeeded!${NC}"
		else
			echo -e "${YELLOW}nginx hot restart fails${NC}"
			return 1
		fi
	else
		echo -e "${YELLOW}nginx binary not found, skipping reload${NC}"
	fi
}

function docker_mysql() {
	# Check if MySQL is configured to use external RDS
	if [ -n "${USE_EXTERNAL_MYSQL:-}" ] && [ "${USE_EXTERNAL_MYSQL}" = "true" ]; then
		echo -e "${GREEN}Skipping local MySQL deployment (using external RDS)${NC}"
		return 0
	fi

	if [ ! -d "${MYSQL_DIR}" ]; then
		echo -e "${YELLOW}MySQL directory not found at ${MYSQL_DIR}, skipping.${NC}" >&2
		return 0
	fi

	cd ${MYSQL_DIR} && chmod  755 mysqldata  -R
	ARGS_MYSQL=$(/usr/sbin/lsof -i :3306 2>/dev/null | grep -v "PID" | awk '{print $2}' || true)
	if [ -n "$ARGS_MYSQL" ]; then
		echo -e "${YELLOW}mysql port is in use${NC}" >&2
		return 1
	fi
	
	if [[ -f "Dockerfile" ]]; then
		docker build -t mysql:5.6 . || echo -e "${RED}Dockerfile not exist${NC}" >&2
	else
		echo -e "${RED}Dockerfile not exist${NC}" >&2
		return 1
	fi

	if [[ -f "docker-compose.yml" ]]; then
		if docker-compose config >/dev/null 2>&1; then
			docker-compose up -d
			echo -e "${GREEN}MySQL started successfully${NC}"
		else
			echo -e "${RED}docker-compose invalid for mysql${NC}" >&2
			return 1
		fi
	else
		echo -e "${RED}compose file not exist${NC}" >&2
		return 1
	fi
}

function docker_nsq() {
	# Check if NSQ is configured to be skipped
	if [ -n "${SKIP_NSQ:-}" ] && [ "${SKIP_NSQ}" = "true" ]; then
		echo -e "${GREEN}Skipping NSQ deployment${NC}"
		return 0
	fi

	if [ ! -d "${NSQ_DIR}" ]; then
		echo -e "${YELLOW}NSQ directory not found at ${NSQ_DIR}, skipping.${NC}" >&2
		return 0
	fi

	cd "${NSQ_DIR}" || return 1
	echo -e "${GREEN}Starting NSQ...${NC}"
	if docker-compose config >/dev/null 2>&1; then
		docker-compose up -d && docker-compose restart
		echo -e "${GREEN}NSQ started successfully${NC}"
	else
		echo -e "${RED}docker-compose invalid for nsq${NC}" >&2
		return 1
	fi
}

function docker_redis() {
	# Check if Redis is configured to be skipped
	if [ -n "${SKIP_REDIS:-}" ] && [ "${SKIP_REDIS}" = "true" ]; then
		echo -e "${GREEN}Skipping Redis deployment${NC}"
		return 0
	fi

	if [ ! -d "${REDIS_DIR}" ]; then
		echo -e "${YELLOW}Redis directory not found at ${REDIS_DIR}, skipping.${NC}" >&2
		return 0
	fi

	cd "${REDIS_DIR}" || return 1
	chmod 755 data -R || true
	ARGS_REDIS=$(docker ps --format "{{.Names}}" | grep redis || true)
	if [ -n "${ARGS_REDIS}" ]; then
	    echo -e "${YELLOW}stop and delete current container${NC}"
	    docker stop ${ARGS_REDIS} && docker rm ${ARGS_REDIS} || true
	fi

	if [[ -f "Dockerfile" ]]; then
	    docker build -t redis:5.0.12 . || echo -e "${RED}Dockerfile not exist${NC}" >&2
	else
	    echo -e "${RED}Dockerfile not exist${NC}" >&2
	    return 1
	fi

	if [[ -f "docker-compose.yml" ]]; then
	    if docker-compose config >/dev/null 2>&1; then
	        docker-compose up -d
			echo -e "${GREEN}Redis started successfully${NC}"
	    else
	        echo -e "${RED}docker-compose invalid for redis${NC}" >&2
	        return 1
	    fi
	else
	    echo -e "${RED}compose file not exist${NC}" >&2
	    return 1
	fi
}

function docker_elk() {
	# Check if ELK is configured to be skipped
	if [ -n "${SKIP_ELK:-}" ] && [ "${SKIP_ELK}" = "true" ]; then
		echo -e "${GREEN}Skipping ELK deployment${NC}"
		return 0
	fi

	if [ ! -d "${ELK_DIR}" ]; then
		echo -e "${YELLOW}ELK directory not found at ${ELK_DIR}, skipping.${NC}" >&2
		return 0
	fi

	cd ${ELK_DIR}
	if grep -R --line-number --quiet 'HOST_IP' .; then
		grep -rlZ 'HOST_IP' . | xargs -0 sed -i "s/HOST_IP/${HOST_IP}/g" || true
	fi

	# create network only if missing; avoid forcing fixed subnet unless configured
	if ! docker network ls --format '{{.Name}}' | grep -q '^staticnet$'; then
		docker network create staticnet || true
	fi

	docker-compose build || true
	docker-compose -f elk.yml up -d || true
	echo -e "${GREEN}Waiting for ES port to start...${NC}"
	sleep 10
	
	port=`lsof -i:9200 | wc -l`
	if [ "$port" -eq "0" ];then
	    echo -e "${YELLOW}es port:9200 start failed${NC}" >&2
	    # Don't exit here if ELK is optional
		if [ -n "${SKIP_ELK_ON_ERROR:-}" ] && [ "${SKIP_ELK_ON_ERROR}" = "true" ]; then
			echo -e "${YELLOW}ELK startup failed but continuing with other services...${NC}"
			return 0
		else
			echo -e "${YELLOW}WARNING: ELK startup failed.${NC}"
			return 1
		fi
	else
	    echo -e "${GREEN}es port:9200 start success and initialize elk${NC}"
	    chmod +x  ${ELK_DIR}/logstash/init.sh 
	    source ./time
	    echo "" | telnet ${HOST_IP} 9200  |grep is |awk '{print $2}' >tmp.txt
	    if cat tmp.txt |grep "character" > /dev/null; then
	        /bin/bash ${ELK_DIR}/logstash/init.sh 
		docker-compose up -d
	    else
		echo -e "${YELLOW}elk initialization failed!${NC}"
	    fi  	
	fi
}

function docker_private() {
	# Adjust private service to work with external MySQL if configured
	if [ -n "${USE_EXTERNAL_MYSQL:-}" ] && [ "${USE_EXTERNAL_MYSQL}" = "true" ]; then
		echo -e "${GREEN}Configuring private service for external MySQL${NC}"
		# Update connection strings in private service if needed
		if [[ -f "${PRIVATE_DIR}/config.toml" ]]; then
			if grep -q "localhost\|127.0.0.1" "${PRIVATE_DIR}/config.toml"; then
				sed -i "s/localhost/${MYSQL_HOST:-localhost}/g" "${PRIVATE_DIR}/config.toml" || true
				sed -i "s/127.0.0.1/${MYSQL_HOST:-127.0.0.1}/g" "${PRIVATE_DIR}/config.toml" || true
			fi
		fi
	fi

	if [ ! -d "${PRIVATE_DIR}" ]; then
		echo -e "${YELLOW}Private directory not found at ${PRIVATE_DIR}, skipping.${NC}" >&2
		return 0
	fi

	cd ${PRIVATE_DIR} || return 1
	if grep -R --line-number --quiet 'HOST_IP' .; then
		grep -rlZ 'HOST_IP' . | xargs -0 sed -i "s/HOST_IP/${HOST_IP}/g" || true
	fi

	if docker-compose config >/dev/null 2>&1; then
		docker-compose up -d && docker-compose restart
		if [ $? -eq 0 ]; then
			echo -e "${GREEN}private-docker start success${NC}"
			return 0
		else
			echo -e "${YELLOW}private-docker start failed${NC}" >&2
			return 1
		fi
	else
		echo -e "${RED}docker-compose invalid for private services${NC}" >&2
		return 1
	fi
}

function run_service_safely() {
	local service_func="$1"
	local service_name="$2"
	
	if declare -f "$service_func" > /dev/null; then
		echo -e "${GREEN}Running $service_name...${NC}"
		if $service_func; then
			echo -e "${GREEN}$service_name completed successfully${NC}"
		else
			echo -e "${YELLOW}WARNING: $service_name failed, but continuing with other services...${NC}"
		fi
	else
		echo -e "${YELLOW}Function $service_func not found, skipping $service_name...${NC}"
	fi
}

# Prepare directories
function prepare_dirs() {
    echo -e "${GREEN}Preparing directories...${NC}"
    
    # Create base data directory
    if [[ ! -d ${BASE_DATA} ]]; then
        echo -e "${GREEN}Creating base data directory: ${BASE_DATA}${NC}"
        mkdir -p "${BASE_DATA}"
    fi
    
    # Copy service configurations to data directory if they don't exist
    for service in nginx mysql redis elk project; do
        service_data_dir="${BASE_DATA}/${service}"
        service_src_dir="${PROJECT_DIR}/services/${service}"
        
        if [[ -d "${service_src_dir}" ]] && [[ ! -d "${service_data_dir}" ]]; then
            echo -e "${GREEN}Setting up ${service} configuration${NC}"
            mkdir -p "${service_data_dir}"
            
            # Copy configuration files
            if [[ -d "${service_src_dir}/config" ]]; then
                cp -r "${service_src_dir}/config/"* "${service_data_dir}/" 2>/dev/null || true
            fi
            
            # Special handling for nginx vhosts
            if [[ "${service}" == "nginx" ]] && [[ -d "${service_src_dir}/vhost" ]]; then
                mkdir -p "${service_data_dir}/vhost"
                cp -r "${service_src_dir}/vhost/"* "${service_data_dir}/vhost/" 2>/dev/null || true
            fi
        fi
    done
    
    # Ensure data subdirectories exist
    for subdir in nginx/mysql nginx/vhost nginx/html nginx/logs mysql/data mysql/conf mysql/log redis/data elk/elasticsearch/data elk/elasticsearch/config elk/kibana/config project/backend; do
        mkdir -p "${BASE_DATA}/${subdir}"
    done
    
    echo -e "${GREEN}Directories prepared${NC}"
}

# Start services using docker-compose
function start_services() {
    echo -e "${GREEN}Starting services...${NC}"
    
    cd "${PROJECT_DIR}"
    
    # Pull latest images
    echo -e "${GREEN}Pulling latest images...${NC}"
    docker-compose pull || true
    
    # Build services if needed
    echo -e "${GREEN}Building services...${NC}"
    docker-compose build || true
    
    # Start all services
    echo -e "${GREEN}Starting all services...${NC}"
    docker-compose up -d
    
    # Wait a bit for services to start
    sleep 10
    
    # Show service status
    echo -e "${GREEN}Service status:${NC}"
    docker-compose ps
}

# Configure nginx
function configure_nginx() {
    echo -e "${GREEN}Configuring Nginx...${NC}"
    
    if [ -n "${DOMAINNAME}" ]; then
        echo -e "${GREEN}Updating domain name in Nginx configs${NC}"
        if grep -R --line-number --quiet 'domain_name' /data/nginx/vhost/; then
            grep -rlZ 'domain_name' /data/nginx/vhost/ | xargs -0 sed -i "s/domain_name/${DOMAINNAME}/g" || true
        fi
    fi
    
    # Reload nginx configuration
    if docker-compose ps | grep -q nginx; then
        echo -e "${GREEN}Reloading Nginx configuration${NC}"
        docker-compose exec nginx nginx -s reload || true
    fi
}

function main() {
  echo -e "${GREEN}Starting full project deployment...${NC}"
  
  verify_prerequisites
  prepare_install
  prepare_dir
  
  # Run services with error handling - if one fails, continue with others
  run_service_safely install_nginx "Nginx installation"
  run_service_safely docker_mysql "MySQL deployment" 
  run_service_safely docker_nsq "NSQ deployment"
  run_service_safely docker_redis "Redis deployment"
  run_service_safely docker_elk "ELK deployment"
  run_service_safely deploy_private "Private project deployment"
  run_service_safely docker_private "Private service deployment"
  
  echo -e "${GREEN}Deployment process completed. Some services may have been skipped based on configuration.${NC}"
  echo
  echo -e "${GREEN}Services are now running. You can check their status with:${NC}"
  echo -e "${GREEN}  cd ${PROJECT_DIR} && docker-compose ps${NC}"
  echo
  echo -e "${GREEN}Access your application at: http://${DOMAINNAME:-localhost}${NC}"
  echo
  echo -e "${GREEN}For troubleshooting, check:${NC}"
  echo -e "${GREEN}  - Documentation: docs/installation.md${NC}"
  echo -e "${GREEN}  - Logs: docker-compose logs <service-name>${NC}"
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi