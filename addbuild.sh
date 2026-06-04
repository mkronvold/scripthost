#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BUILD_DIR="${ROOT_DIR}/build"
MAX_CONFIGMAP_BYTES="${MAX_CONFIGMAP_BYTES:-1048576}"

BUILD_DIR="${BUILD_DIR:-$DEFAULT_BUILD_DIR}"
BUILD_CONFIGMAP_YAML="${BUILD_CONFIGMAP_YAML:-${ROOT_DIR}/build-configmap.yaml}"

usage() {
    echo "Usage: $0 <source-file> <relative-destination>" >&2
    echo "Example: $0 /path/to/k8s-login usr/local/bin/k8s-login" >&2
}

[ "$#" -eq 2 ] || {
    usage
    exit 1
}

source_file="$1"
relative_dest="$2"

[ -f "$source_file" ] || {
    echo "Source file not found: $source_file" >&2
    exit 1
}

case "$relative_dest" in
    /*)
        echo "Destination must be relative to BUILD_DIR: $relative_dest" >&2
        exit 1
        ;;
esac

install -d -m 0755 "$BUILD_DIR"
install -d -m 0755 "${BUILD_DIR}/$(dirname "$relative_dest")"
install -m 0644 "$source_file" "${BUILD_DIR}/${relative_dest}"

file_size="$(wc -c < "${BUILD_DIR}/${relative_dest}" | tr -d '[:space:]')"
if [ "$file_size" -gt "$MAX_CONFIGMAP_BYTES" ]; then
    echo "Warning: ${relative_dest} is ${file_size} bytes and is larger than a typical ConfigMap size limit (${MAX_CONFIGMAP_BYTES} bytes)." >&2
fi

echo "Added ${relative_dest} to ${BUILD_DIR}"

if [ -x "${ROOT_DIR}/updatebuildconfigmap.sh" ]; then
    UPDATEBUILDCONFIGMAP_APPLY=0 \
    UPDATEBUILDCONFIGMAP_PROMPT=0 \
    UPDATEBUILDCONFIGMAP_POST_APPLY_PROMPT=0 \
        "${ROOT_DIR}/updatebuildconfigmap.sh"
    if [ -f "$BUILD_CONFIGMAP_YAML" ]; then
        configmap_size="$(wc -c < "$BUILD_CONFIGMAP_YAML" | tr -d '[:space:]')"
        if [ "$configmap_size" -gt "$MAX_CONFIGMAP_BYTES" ]; then
            echo "Warning: generated ${BUILD_CONFIGMAP_YAML} is ${configmap_size} bytes and may be too large to apply as a ConfigMap." >&2
        fi
    fi
fi

printf 'Run updatebuildconfigmap.sh and apply the updated build ConfigMap now? [y/N] '
read -r reply
case "$reply" in
    [Yy]|[Yy][Ee][Ss])
        exec env \
            UPDATEBUILDCONFIGMAP_APPLY=1 \
            UPDATEBUILDCONFIGMAP_PROMPT=0 \
            "${ROOT_DIR}/updatebuildconfigmap.sh"
        ;;
esac

echo "Skipped build ConfigMap update"
