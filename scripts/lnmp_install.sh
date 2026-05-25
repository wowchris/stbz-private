#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "${BASE_DIR}/main.sh"
Get_System_Name

if [ "${USER:-}" != "root" ]; then
  echo "ERROR: Please run as root."
  exit 1
fi

cat <<EOF
Detected operating system: ${DISTRO}
Package manager: ${PM}
One-click LNMP-style deployment will install Docker, Docker Compose, and start the private stack.
EOF

install_docker() {
  case "${PM}" in
    yum)
      bash "${BASE_DIR}/docker_install.sh"
      ;;
    apt)
      bash "${BASE_DIR}/docker_install.sh"
      ;;
    *)
      echo "Unsupported OS for one-click deployment: ${DISTRO}"
      exit 1
      ;;
  esac
}

install_docker_compose() {
  bash "${BASE_DIR}/docker-compose_install.sh"
}

prepare_environment() {
  if [ "${PM}" = "yum" ]; then
    if command -v firewall-cmd >/dev/null 2>&1; then
      systemctl stop firewalld || true
      systemctl disable firewalld || true
    fi
    if command -v setenforce >/dev/null 2>&1; then
      setenforce 0 || true
    fi
  elif [ "${PM}" = "apt" ]; then
    if command -v ufw >/dev/null 2>&1; then
      ufw disable || true
    fi
  fi
}

main() {
  prepare_environment
  install_docker
  install_docker_compose

  echo "\nRunning repository deployment script..."
  cd "${BASE_DIR}/.." || exit 1
  bash ./install.sh
}

main "$@"
