#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SCRIPTS_DIR="${ROOT_DIR}/scripts"
DEFAULT_BUILD_DIR="${ROOT_DIR}/build"

CADDYFILE="${CADDYFILE:-${ROOT_DIR}/Caddyfile}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$DEFAULT_SCRIPTS_DIR}"
BUILD_DIR="${BUILD_DIR:-$DEFAULT_BUILD_DIR}"
IMAGE="${IMAGE:-caddy:2-alpine}"
CONTAINER_NAME="${CONTAINER_NAME:-scripthost}"
HOST_PORT="${HOST_PORT:-8080}"

ensure_content_dir() {
    local dir_path="$1"
    local default_path="$2"
    local label="$3"

    if [ -d "$dir_path" ]; then
        return
    fi

    if [ "$dir_path" = "$default_path" ]; then
        mkdir -p "$dir_path"
        return
    fi

    echo "${label} directory not found: ${dir_path}" >&2
    exit 1
}

[ -f "$CADDYFILE" ] || { echo "Caddyfile not found: $CADDYFILE" >&2; exit 1; }
ensure_content_dir "$SCRIPTS_DIR" "$DEFAULT_SCRIPTS_DIR" "Scripts"
ensure_content_dir "$BUILD_DIR" "$DEFAULT_BUILD_DIR" "Build"
command -v docker >/dev/null 2>&1 || { echo "Missing required command: docker" >&2; exit 1; }

if docker ps -aq -f "name=^/${CONTAINER_NAME}$" | grep -q .; then
    docker rm -f "$CONTAINER_NAME" >/dev/null
fi

docker run -d \
    --name "$CONTAINER_NAME" \
    -p "${HOST_PORT}:8080" \
    -v "${CADDYFILE}:/etc/caddy/Caddyfile:ro" \
    -v "${SCRIPTS_DIR}:/srv/scripts:ro" \
    -v "${BUILD_DIR}:/srv/build:ro" \
    "$IMAGE" \
    caddy run --config /etc/caddy/Caddyfile --adapter caddyfile --watch >/dev/null

echo "Started ${CONTAINER_NAME} on http://127.0.0.1:${HOST_PORT}"
echo "Using SCRIPTS_DIR=${SCRIPTS_DIR}"
echo "Using BUILD_DIR=${BUILD_DIR}"
