#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-scripthost}"

command -v docker >/dev/null 2>&1 || { echo "Missing required command: docker" >&2; exit 1; }

if docker ps -aq -f "name=^/${CONTAINER_NAME}$" | grep -q .; then
    docker rm -f "$CONTAINER_NAME" >/dev/null
    echo "Stopped ${CONTAINER_NAME}"
else
    echo "Container ${CONTAINER_NAME} is not running"
fi
