#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BUILD_DIR="${ROOT_DIR}/build"

APP_NAME="${APP_NAME:-scripthost}"
NAMESPACE="${NAMESPACE:-default}"
BUILD_DIR="${BUILD_DIR:-$DEFAULT_BUILD_DIR}"
BUILD_CONFIGMAP_NAME="${BUILD_CONFIGMAP_NAME:-${APP_NAME}-build}"
BUILD_CONFIGMAP_YAML="${BUILD_CONFIGMAP_YAML:-${ROOT_DIR}/build-configmap.yaml}"
MAX_CONFIGMAP_BYTES="${MAX_CONFIGMAP_BYTES:-1048576}"
UPDATEBUILDCONFIGMAP_APPLY="${UPDATEBUILDCONFIGMAP_APPLY:-1}"
UPDATEBUILDCONFIGMAP_PROMPT="${UPDATEBUILDCONFIGMAP_PROMPT:-1}"
UPDATEBUILDCONFIGMAP_POST_APPLY_PROMPT="${UPDATEBUILDCONFIGMAP_POST_APPLY_PROMPT:-1}"

command -v kubectl >/dev/null 2>&1 || { echo "Missing required command: kubectl" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "Missing required command: tar" >&2; exit 1; }
[ -f "${ROOT_DIR}/k8s-update-helpers.sh" ] || { echo "Missing helper: ${ROOT_DIR}/k8s-update-helpers.sh" >&2; exit 1; }
[ -d "$BUILD_DIR" ] || { echo "Build directory not found: $BUILD_DIR" >&2; exit 1; }

source "${ROOT_DIR}/k8s-update-helpers.sh"

if ! find "$BUILD_DIR" -type f -print -quit | grep -q .; then
    echo "No files found in $BUILD_DIR" >&2
    exit 1
fi

archive_file="$(mktemp "${TMPDIR:-/tmp}/scripthost-build.XXXXXX.tgz")"
cleanup() {
    rm -f -- "$archive_file"
}
trap cleanup EXIT INT TERM

tar -C "$BUILD_DIR" -czf "$archive_file" .

archive_size="$(wc -c < "$archive_file" | tr -d '[:space:]')"
if [ "$archive_size" -gt "$MAX_CONFIGMAP_BYTES" ]; then
    echo "Warning: build archive is ${archive_size} bytes and may be too large to fit in a ConfigMap." >&2
fi

kubectl -n "$NAMESPACE" create configmap "$BUILD_CONFIGMAP_NAME" \
    --from-file=build.tgz="$archive_file" \
    --dry-run=client -o yaml > "$BUILD_CONFIGMAP_YAML"

configmap_size="$(wc -c < "$BUILD_CONFIGMAP_YAML" | tr -d '[:space:]')"
echo "Generated ${BUILD_CONFIGMAP_YAML} from ${BUILD_DIR}"
if [ "$configmap_size" -gt "$MAX_CONFIGMAP_BYTES" ]; then
    echo "Warning: ${BUILD_CONFIGMAP_YAML} is ${configmap_size} bytes and may be too large to apply as a ConfigMap." >&2
fi

if [ "$UPDATEBUILDCONFIGMAP_APPLY" != "1" ]; then
    exit 0
fi

if [ "$UPDATEBUILDCONFIGMAP_PROMPT" = "1" ]; then
    printf 'Apply %s to namespace %s now? [y/N] ' "$BUILD_CONFIGMAP_YAML" "$NAMESPACE"
    read -r reply
    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) ;;
        *)
            echo "Skipped applying ${BUILD_CONFIGMAP_YAML}"
            exit 0
            ;;
    esac
fi

kubectl -n "$NAMESPACE" apply -f "$BUILD_CONFIGMAP_YAML"
echo "Applied ${BUILD_CONFIGMAP_YAML} to namespace ${NAMESPACE}"

prompt_post_apply_action \
    "$UPDATEBUILDCONFIGMAP_POST_APPLY_PROMPT" \
    "$NAMESPACE" \
    "$APP_NAME" \
    "$BUILD_DIR" \
    "/srv/build" \
    "build content"
