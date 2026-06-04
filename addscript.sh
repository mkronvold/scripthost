#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SCRIPTS_DIR="${ROOT_DIR}/scripts"
MAX_CONFIGMAP_BYTES="${MAX_CONFIGMAP_BYTES:-1048576}"

SCRIPTS_DIR="${SCRIPTS_DIR:-$DEFAULT_SCRIPTS_DIR}"
CONFIGMAP_YAML="${CONFIGMAP_YAML:-${ROOT_DIR}/configmap.yaml}"

usage() {
    echo "Usage: $0 <script-file>" >&2
    echo "Example: $0 install_custom" >&2
}

[ "$#" -eq 1 ] || {
    usage
    exit 1
}

source_arg="$1"
if [ -f "$source_arg" ]; then
    source_file="$source_arg"
else
    echo "Script file not found: $source_arg" >&2
    exit 1
fi

install -d -m 0755 "$SCRIPTS_DIR"
target_file="${SCRIPTS_DIR}/$(basename "$source_file")"
install -m 0555 "$source_file" "$target_file"

script_size="$(wc -c < "$target_file" | tr -d '[:space:]')"
if [ "$script_size" -gt "$MAX_CONFIGMAP_BYTES" ]; then
    echo "Warning: $(basename "$target_file") is ${script_size} bytes and is larger than a typical ConfigMap size limit (${MAX_CONFIGMAP_BYTES} bytes)." >&2
fi

echo "Added $(basename "$target_file") to ${SCRIPTS_DIR}"

if [ -x "${ROOT_DIR}/updatescriptconfigmap.sh" ]; then
    UPDATESCRIPTCONFIGMAP_APPLY=0 \
    UPDATESCRIPTCONFIGMAP_PROMPT=0 \
    UPDATESCRIPTCONFIGMAP_POST_APPLY_PROMPT=0 \
        "${ROOT_DIR}/updatescriptconfigmap.sh"
    if [ -f "$CONFIGMAP_YAML" ]; then
        configmap_size="$(wc -c < "$CONFIGMAP_YAML" | tr -d '[:space:]')"
        if [ "$configmap_size" -gt "$MAX_CONFIGMAP_BYTES" ]; then
            echo "Warning: generated ${CONFIGMAP_YAML} is ${configmap_size} bytes and may be too large to apply as a ConfigMap." >&2
        fi
    fi
fi

printf 'Run updatescriptconfigmap.sh and apply the updated scripts ConfigMap now? [y/N] '
read -r reply
case "$reply" in
    [Yy]|[Yy][Ee][Ss])
        exec env \
            UPDATESCRIPTCONFIGMAP_APPLY=1 \
            UPDATESCRIPTCONFIGMAP_PROMPT=0 \
            "${ROOT_DIR}/updatescriptconfigmap.sh"
        ;;
esac

echo "Skipped ConfigMap update"
