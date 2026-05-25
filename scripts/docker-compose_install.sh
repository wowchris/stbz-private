#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [ "${USER:-}" != "root" ]; then
    echo "ERROR: Unable to perform installation as non-root user."
    exit 1
fi

COMPOSE_BIN=/usr/local/bin/docker-compose
mkdir -p "$(dirname "$COMPOSE_BIN")"

if command -v curl >/dev/null 2>&1; then
    curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o "$COMPOSE_BIN"
else
    echo "ERROR: curl is required to install docker-compose."
    exit 1
fi

chmod +x "$COMPOSE_BIN"
ln -sf "$COMPOSE_BIN" /usr/bin/docker-compose

if ! docker-compose --version >/dev/null 2>&1; then
    echo "ERROR: docker-compose install failed."
    exit 1
fi

echo "docker-compose install success"
