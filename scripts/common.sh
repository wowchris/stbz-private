#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"


if ! docker --version &> /dev/null
then
	echo "docker no exist and Need to install it now."
	. "${BASE_DIR}/docker_install.sh"
else
	echo "docker is exist." 
	
fi


if ! docker-compose version &> /dev/null
then
	echo "docker-compose no exist and Need to install it now."
	. "${BASE_DIR}/docker-compose_install.sh"
else
	echo "docker-compose is exist."
	
fi
