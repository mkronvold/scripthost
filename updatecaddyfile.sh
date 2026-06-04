#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_NAME="${APP_NAME:-scripthost}"
NAMESPACE="${NAMESPACE:-default}"
CADDYFILE="${CADDYFILE:-${ROOT_DIR}/Caddyfile}"
CONFIGMAP_NAME="${CONFIGMAP_NAME:-${APP_NAME}-caddyfile}"
REMOTE_CADDYFILE_PATH="${REMOTE_CADDYFILE_PATH:-/etc/caddy/Caddyfile}"

command -v kubectl >/dev/null 2>&1 || { echo "Missing required command: kubectl" >&2; exit 1; }
[ -f "$CADDYFILE" ] || { echo "Caddyfile not found: $CADDYFILE" >&2; exit 1; }
[ -f "${ROOT_DIR}/k8s-update-helpers.sh" ] || { echo "Missing helper: ${ROOT_DIR}/k8s-update-helpers.sh" >&2; exit 1; }

source "${ROOT_DIR}/k8s-update-helpers.sh"

kubectl -n "$NAMESPACE" create configmap "$CONFIGMAP_NAME" \
    --from-file=Caddyfile="$CADDYFILE" \
    --dry-run=client -o yaml | kubectl apply -f -

pod_count=0
while IFS= read -r pod; do
    [ -n "$pod" ] || continue
    pod_count=1
    kubectl -n "$NAMESPACE" exec "$pod" -- sh -c "mkdir -p \"$(dirname "$REMOTE_CADDYFILE_PATH")\""
    kubectl -n "$NAMESPACE" exec -i "$pod" -- sh -c "cat > \"$REMOTE_CADDYFILE_PATH\"" < "$CADDYFILE"
    echo "Updated ${REMOTE_CADDYFILE_PATH} in pod ${pod}"
done < <(list_app_pods "$NAMESPACE" "$APP_NAME")

if [ "$pod_count" -ne 1 ]; then
    echo "Updated ConfigMap ${CONFIGMAP_NAME}, but no pods matched app=${APP_NAME} in namespace ${NAMESPACE}" >&2
    exit 1
fi

echo "Updated ${CONFIGMAP_NAME} and pushed ${CADDYFILE} into running pods. Caddy --watch will pick up the changes automatically."
