#!/usr/bin/env bash
# Script de déploiement K8s — exécuté sur la VM via SSH par le pipeline
# Variables requises :
#   GHCR_USER, GHCR_TOKEN, GHCR_EMAIL
#   BACKEND_IMAGE, FRONTEND_IMAGE
#   DB_USER, DB_PASSWORD, DB_NAME
# Usage : ./deploy.sh
set -euo pipefail

: "${BACKEND_IMAGE:?must be set}"
: "${FRONTEND_IMAGE:?must be set}"
: "${GHCR_USER:?must be set}"
: "${GHCR_TOKEN:?must be set}"
: "${DB_USER:?must be set}"
: "${DB_PASSWORD:?must be set}"
: "${DB_NAME:?must be set}"

MANIFESTS_DIR="$(dirname "$(realpath "$0")")"
NS="tp-app"

export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

echo "[deploy] applying namespace"
kubectl apply -f "$MANIFESTS_DIR/00-namespace.yaml"

echo "[deploy] creating/updating db-credentials Secret"
kubectl -n "$NS" create secret generic db-credentials \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=DB_NAME="$DB_NAME" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[deploy] creating/updating ghcr-pull Secret (imagePullSecret)"
kubectl -n "$NS" create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username="$GHCR_USER" \
  --docker-password="$GHCR_TOKEN" \
  --docker-email="${GHCR_EMAIL:-noreply@github.com}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[deploy] applying ConfigMap"
kubectl apply -f "$MANIFESTS_DIR/11-configmap.yaml"

echo "[deploy] applying DB Deployment"
kubectl apply -f "$MANIFESTS_DIR/20-db.yaml"

echo "[deploy] rendering and applying backend (image=$BACKEND_IMAGE)"
sed "s|__BACKEND_IMAGE__|$BACKEND_IMAGE|g" "$MANIFESTS_DIR/30-backend.yaml" | kubectl apply -f -

echo "[deploy] rendering and applying frontend (image=$FRONTEND_IMAGE)"
sed "s|__FRONTEND_IMAGE__|$FRONTEND_IMAGE|g" "$MANIFESTS_DIR/40-frontend.yaml" | kubectl apply -f -

echo "[deploy] applying ServiceMonitor for Prometheus (ignore if CRDs absent)"
kubectl apply -f "$MANIFESTS_DIR/50-servicemonitor.yaml" 2>/dev/null || echo "[deploy] ServiceMonitor CRD not present yet, skip"

echo "[deploy] forcing rollout restart to pull new images"
kubectl -n "$NS" rollout restart deployment/backend deployment/frontend

echo "[deploy] waiting for rollouts"
kubectl -n "$NS" rollout status deployment/db --timeout=180s
kubectl -n "$NS" rollout status deployment/backend --timeout=180s
kubectl -n "$NS" rollout status deployment/frontend --timeout=180s

echo "[deploy] done"
kubectl -n "$NS" get pods,svc
