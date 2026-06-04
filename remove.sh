#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-scripthost}"
NAMESPACE="${NAMESPACE:-default}"

command -v kubectl >/dev/null 2>&1 || { echo "Missing required command: kubectl" >&2; exit 1; }

kubectl -n "$NAMESPACE" delete service "$APP_NAME" --ignore-not-found
kubectl -n "$NAMESPACE" delete deployment "$APP_NAME" --ignore-not-found
kubectl -n "$NAMESPACE" delete configmap "${APP_NAME}-caddyfile" --ignore-not-found
kubectl -n "$NAMESPACE" delete configmap "${APP_NAME}-scripts" --ignore-not-found
kubectl -n "$NAMESPACE" delete configmap "${APP_NAME}-build" --ignore-not-found

echo "Removed ${APP_NAME} resources from namespace ${NAMESPACE}"
