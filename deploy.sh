#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SCRIPTS_DIR="${ROOT_DIR}/scripts"
DEFAULT_BUILD_DIR="${ROOT_DIR}/build"

CADDYFILE="${CADDYFILE:-${ROOT_DIR}/Caddyfile}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$DEFAULT_SCRIPTS_DIR}"
BUILD_DIR="${BUILD_DIR:-$DEFAULT_BUILD_DIR}"
APP_NAME="${APP_NAME:-scripthost}"
NAMESPACE="${NAMESPACE:-default}"
IMAGE="${IMAGE:-caddy:2-alpine}"
CONFIGMAP_YAML="${CONFIGMAP_YAML:-${ROOT_DIR}/configmap.yaml}"
BUILD_CONFIGMAP_YAML="${BUILD_CONFIGMAP_YAML:-${ROOT_DIR}/build-configmap.yaml}"

[ -f "$CADDYFILE" ] || { echo "Caddyfile not found: $CADDYFILE" >&2; exit 1; }
[ -d "$SCRIPTS_DIR" ] || { echo "Scripts directory not found: $SCRIPTS_DIR" >&2; exit 1; }
[ -f "${SCRIPTS_DIR}/install" ] || { echo "Missing script: ${SCRIPTS_DIR}/install" >&2; exit 1; }
[ -f "${SCRIPTS_DIR}/install_wsl" ] || { echo "Missing script: ${SCRIPTS_DIR}/install_wsl" >&2; exit 1; }
[ -f "${SCRIPTS_DIR}/install_local" ] || { echo "Missing script: ${SCRIPTS_DIR}/install_local" >&2; exit 1; }
[ -x "${ROOT_DIR}/updatescriptconfigmap.sh" ] || { echo "Missing helper: ${ROOT_DIR}/updatescriptconfigmap.sh" >&2; exit 1; }
[ -x "${ROOT_DIR}/updatebuildconfigmap.sh" ] || { echo "Missing helper: ${ROOT_DIR}/updatebuildconfigmap.sh" >&2; exit 1; }
[ -d "$BUILD_DIR" ] || { echo "Build directory not found: $BUILD_DIR" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Missing required command: kubectl" >&2; exit 1; }

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE" >/dev/null

kubectl -n "$NAMESPACE" create configmap "${APP_NAME}-caddyfile" \
    --from-file=Caddyfile="$CADDYFILE" \
    --dry-run=client -o yaml | kubectl apply -f -

UPDATESCRIPTCONFIGMAP_APPLY=0 UPDATESCRIPTCONFIGMAP_PROMPT=0 UPDATESCRIPTCONFIGMAP_POST_APPLY_PROMPT=0 \
APP_NAME="$APP_NAME" NAMESPACE="$NAMESPACE" SCRIPTS_DIR="$SCRIPTS_DIR" CONFIGMAP_YAML="$CONFIGMAP_YAML" \
    "${ROOT_DIR}/updatescriptconfigmap.sh"

kubectl -n "$NAMESPACE" apply -f "$CONFIGMAP_YAML"

UPDATEBUILDCONFIGMAP_APPLY=0 UPDATEBUILDCONFIGMAP_PROMPT=0 UPDATEBUILDCONFIGMAP_POST_APPLY_PROMPT=0 \
APP_NAME="$APP_NAME" NAMESPACE="$NAMESPACE" BUILD_DIR="$BUILD_DIR" BUILD_CONFIGMAP_YAML="$BUILD_CONFIGMAP_YAML" \
    "${ROOT_DIR}/updatebuildconfigmap.sh"

kubectl -n "$NAMESPACE" apply -f "$BUILD_CONFIGMAP_YAML"

kubectl -n "$NAMESPACE" apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      initContainers:
        - name: caddyfile-init
          image: ${IMAGE}
          command:
            - sh
            - -c
            - |
              mkdir -p /etc/caddy
              cp -f /seed-caddyfile/Caddyfile /etc/caddy/Caddyfile
          volumeMounts:
            - name: caddyfile-seed
              mountPath: /seed-caddyfile
              readOnly: true
            - name: caddyfile
              mountPath: /etc/caddy
        - name: scripts-init
          image: ${IMAGE}
          command:
            - sh
            - -c
            - |
              mkdir -p /srv/scripts
              if find /seed-scripts -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
                tar -C /seed-scripts -cf - . | tar -C /srv/scripts -xf -
              fi
          volumeMounts:
            - name: scripts-seed
              mountPath: /seed-scripts
              readOnly: true
            - name: scripts
              mountPath: /srv/scripts
        - name: build-init
          image: ${IMAGE}
          command:
            - sh
            - -c
            - |
              mkdir -p /srv/build
              if [ -f /seed-build/build.tgz ]; then
                tar -xzf /seed-build/build.tgz -C /srv/build
              fi
          volumeMounts:
            - name: build-seed
              mountPath: /seed-build
              readOnly: true
            - name: build
              mountPath: /srv/build
      containers:
        - name: caddy
          image: ${IMAGE}
          args:
            - caddy
            - run
            - --config
            - /etc/caddy/Caddyfile
            - --adapter
            - caddyfile
            - --watch
          ports:
            - containerPort: 8080
              name: http
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
          volumeMounts:
            - name: caddyfile
              mountPath: /etc/caddy
            - name: scripts
              mountPath: /srv/scripts
            - name: build
              mountPath: /srv/build
      volumes:
        - name: caddyfile-seed
          configMap:
            name: ${APP_NAME}-caddyfile
        - name: caddyfile
          emptyDir: {}
        - name: scripts-seed
          configMap:
            name: ${APP_NAME}-scripts
            defaultMode: 0555
        - name: scripts
          emptyDir: {}
        - name: build-seed
          configMap:
            name: ${APP_NAME}-build
        - name: build
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
spec:
  selector:
    app: ${APP_NAME}
  ports:
    - name: http
      port: 8080
      targetPort: http
EOF

echo "Deployed ${APP_NAME} in namespace ${NAMESPACE}"
echo "Using SCRIPTS_DIR=${SCRIPTS_DIR}"
echo "Generated CONFIGMAP_YAML=${CONFIGMAP_YAML}"
echo "Using BUILD_DIR=${BUILD_DIR}"
echo "Generated BUILD_CONFIGMAP_YAML=${BUILD_CONFIGMAP_YAML}"
