#!/usr/bin/env bash
# ============================================================
# Création de la VM Azure pour le TP DevOps
# Exécute ce script UNE SEULE FOIS pour provisionner la VM.
# Prérequis : az CLI installé et connecté (az login)
# ============================================================
set -euo pipefail

# ---------- Paramètres (à adapter si besoin) ----------
RG="tp-devops-rg"
LOCATION="francecentral"          # proche de toi, étudiant
VM_NAME="tp-k3s"
VM_SIZE="Standard_B2s"            # 2 vCPU / 4 Go RAM — assez pour K3s
ADMIN="azureuser"
IMAGE="Ubuntu2204"
SSH_KEY_FILE="$HOME/.ssh/id_ed25519_tp"
NSG_NAME="${VM_NAME}-nsg"
PUBLIC_IP_NAME="${VM_NAME}-pip"

# ---------- 1) Clé SSH dédiée au TP ----------
if [ ! -f "$SSH_KEY_FILE" ]; then
  echo "[ssh] génération de la clé $SSH_KEY_FILE"
  ssh-keygen -t ed25519 -f "$SSH_KEY_FILE" -N "" -C "tp-devops-kevin"
fi

# ---------- 2) Resource group ----------
echo "[az] creating RG $RG in $LOCATION"
az group create --name "$RG" --location "$LOCATION" -o table

# ---------- 3) VM ----------
echo "[az] creating VM $VM_NAME ($VM_SIZE)"
az vm create \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --image "$IMAGE" \
  --size "$VM_SIZE" \
  --admin-username "$ADMIN" \
  --ssh-key-values "${SSH_KEY_FILE}.pub" \
  --public-ip-address "$PUBLIC_IP_NAME" \
  --nsg-rule SSH \
  --output table

# ---------- 4) Ouvrir port 30080 (NodePort frontend) ----------
echo "[az] opening port 30080 on NSG"
az vm open-port \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --port 30080 \
  --priority 1010 \
  --output table

# ---------- 5) Récupérer l'IP publique ----------
VM_IP=$(az vm show -d -g "$RG" -n "$VM_NAME" --query publicIps -o tsv)
echo ""
echo "============================================"
echo "✅ VM prête"
echo "  SSH   : ssh -i $SSH_KEY_FILE $ADMIN@$VM_IP"
echo "  IP    : $VM_IP"
echo "  User  : $ADMIN"
echo ""
echo "Secrets GitHub à configurer :"
echo "  VM_HOST    = $VM_IP"
echo "  VM_USER    = $ADMIN"
echo "  VM_SSH_KEY = (contenu de $SSH_KEY_FILE)"
echo "============================================"
