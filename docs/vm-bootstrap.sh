#!/usr/bin/env bash
# ============================================================
# Bootstrap de la VM : Docker + Docker Compose + K3s
# Lancé UNE SEULE FOIS sur la VM via SSH après sa création.
# ============================================================
set -euo pipefail

echo "[bootstrap] updating apt"
sudo apt-get update -y
sudo apt-get upgrade -y

echo "[bootstrap] installing prerequisites"
sudo apt-get install -y ca-certificates curl gnupg jq

echo "[bootstrap] installing Docker (official script)"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo usermod -aG docker "$USER" || true

echo "[bootstrap] installing K3s (lightweight Kubernetes)"
if ! command -v k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | sh -
fi

echo "[bootstrap] making kubeconfig readable by $USER"
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$USER":"$USER" "$HOME/.kube/config"

echo "[bootstrap] versions"
docker --version
sudo k3s --version
kubectl get nodes

echo "[bootstrap] done ✅"
