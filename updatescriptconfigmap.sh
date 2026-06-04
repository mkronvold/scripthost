#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SCRIPTS_DIR="${ROOT_DIR}/scripts"

APP_NAME="${APP_NAME:-scripthost}"
NAMESPACE="${NAMESPACE:-default}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$DEFAULT_SCRIPTS_DIR}"
CONFIGMAP_NAME="${CONFIGMAP_NAME:-${APP_NAME}-scripts}"
CONFIGMAP_YAML="${CONFIGMAP_YAML:-${ROOT_DIR}/configmap.yaml}"
MAX_CONFIGMAP_BYTES="${MAX_CONFIGMAP_BYTES:-1048576}"
UPDATESCRIPTCONFIGMAP_APPLY="${UPDATESCRIPTCONFIGMAP_APPLY:-1}"
UPDATESCRIPTCONFIGMAP_PROMPT="${UPDATESCRIPTCONFIGMAP_PROMPT:-1}"
UPDATESCRIPTCONFIGMAP_POST_APPLY_PROMPT="${UPDATESCRIPTCONFIGMAP_POST_APPLY_PROMPT:-1}"

command -v kubectl >/dev/null 2>&1 || { echo "Missing required command: kubectl" >&2; exit 1; }
[ -f "${ROOT_DIR}/k8s-update-helpers.sh" ] || { echo "Missing helper: ${ROOT_DIR}/k8s-update-helpers.sh" >&2; exit 1; }
[ -d "$SCRIPTS_DIR" ] || { echo "Scripts directory not found: $SCRIPTS_DIR" >&2; exit 1; }
[ -f "${SCRIPTS_DIR}/install" ] || { echo "Missing script: ${SCRIPTS_DIR}/install" >&2; exit 1; }
[ -f "${SCRIPTS_DIR}/install_wsl" ] || { echo "Missing script: ${SCRIPTS_DIR}/install_wsl" >&2; exit 1; }
[ -f "${SCRIPTS_DIR}/install_local" ] || { echo "Missing script: ${SCRIPTS_DIR}/install_local" >&2; exit 1; }

source "${ROOT_DIR}/k8s-update-helpers.sh"

script_args=()
while IFS= read -r -d '' script_file; do
    script_args+=(--from-file="$script_file")
done < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -print0 | sort -z)

[ "${#script_args[@]}" -gt 0 ] || { echo "No scripts found in $SCRIPTS_DIR" >&2; exit 1; }

kubectl -n "$NAMESPACE" create configmap "$CONFIGMAP_NAME" \
    "${script_args[@]}" \
    --dry-run=client -o yaml > "$CONFIGMAP_YAML"

configmap_size="$(wc -c < "$CONFIGMAP_YAML" | tr -d '[:space:]')"
echo "Generated ${CONFIGMAP_YAML} from ${SCRIPTS_DIR}"
if [ "$configmap_size" -gt "$MAX_CONFIGMAP_BYTES" ]; then
    echo "Warning: ${CONFIGMAP_YAML} is ${configmap_size} bytes and may be too large to apply as a ConfigMap." >&2
fi

if [ "$UPDATESCRIPTCONFIGMAP_APPLY" != "1" ]; then
    exit 0
fi

if [ "$UPDATESCRIPTCONFIGMAP_PROMPT" = "1" ]; then
    printf 'Apply %s to namespace %s now? [y/N] ' "$CONFIGMAP_YAML" "$NAMESPACE"
    read -r reply
    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) ;;
        *)
            echo "Skipped applying ${CONFIGMAP_YAML}"
            exit 0
            ;;
    esac
fi

kubectl -n "$NAMESPACE" apply -f "$CONFIGMAP_YAML"
echo "Applied ${CONFIGMAP_YAML} to namespace ${NAMESPACE}"

prompt_post_apply_action \
    "$UPDATESCRIPTCONFIGMAP_POST_APPLY_PROMPT" \
    "$NAMESPACE" \
    "$APP_NAME" \
    "$SCRIPTS_DIR" \
    "/srv/scripts" \
    "scripts"
