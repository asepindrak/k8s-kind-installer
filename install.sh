#!/usr/bin/env bash
# install.sh
# Automated installer for Kind cluster + deploy app + install ingress (stable for kind)
# Assumptions:
# - Run inside WSL (Ubuntu) with Docker Desktop WSL integration enabled.
# - Files present in current directory:
#     .env                 (optional, for create-cluster-with-env.sh)
#     create-cluster-with-env.sh
#     deployment.yaml
#     service.yaml
#     ingress.yaml
#
# Usage:
#   chmod +x install.sh
#   sudo ./install.sh
#
set -euo pipefail
IFS=$'\n\t'

CLUSTER_SCRIPT="./create-cluster-with-env.sh"
DEPLOYMENT_FILE="./deployment.yaml"
SERVICE_FILE="./service.yaml"
INGRESS_FILE="./ingress.yaml"
INGRESS_MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml"

log() { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[install]\033[0m %s\n' "$*" >&2; }

ensure_root() {
  if [ "$EUID" -ne 0 ]; then
    err "This script must be run with sudo or as root."
    exit 1
  fi
}

ensure_file() {
  if [ ! -f "$1" ]; then
    err "Required file not found: $1"
    exit 1
  fi
}

check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    err "docker not found. Ensure Docker Desktop with WSL integration is running."
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    err "Docker daemon unreachable. Start Docker Desktop and ensure WSL integration is enabled."
    exit 1
  fi
  log "Docker available."
}

run_create_cluster() {
  if command -v kind >/dev/null 2>&1 && kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME:-wsl-cluster}$"; then
    log "Kind cluster '${CLUSTER_NAME:-wsl-cluster}' already exists. Skipping cluster creation."
    return
  fi

  if [ -x "$CLUSTER_SCRIPT" ]; then
    log "Running cluster creation script: $CLUSTER_SCRIPT"
    # ensure script is executable
    chmod +x "$CLUSTER_SCRIPT"
    "$CLUSTER_SCRIPT"
  else
    err "Cluster creation script not found or not executable: $CLUSTER_SCRIPT"
    exit 1
  fi
}

apply_manifests() {
  log "Applying deployment: $DEPLOYMENT_FILE"
  kubectl apply -f "$DEPLOYMENT_FILE"

  log "Applying service: $SERVICE_FILE"
  kubectl apply -f "$SERVICE_FILE"
}

install_ingress_controller() {
  log "Installing ingress-nginx controller (stable for kind) from: $INGRESS_MANIFEST_URL"
  kubectl apply -f "$INGRESS_MANIFEST_URL"
  log "Waiting for ingress-nginx controller pod to become Ready (timeout 180s)..."
  if ! kubectl wait --namespace ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=180s; then
    err "Ingress controller did not become Ready within timeout. Showing ingress namespace pods and events:"
    kubectl get pods -n ingress-nginx -o wide || true
    kubectl describe pod -n ingress-nginx $(kubectl get pods -n ingress-nginx -o jsonpath='{.items[0].metadata.name}') || true
    return 1
  fi
  log "Ingress controller Ready."
}

apply_ingress_resource() {
  if [ -f "$INGRESS_FILE" ]; then
    log "Applying ingress resource: $INGRESS_FILE"
    kubectl apply -f "$INGRESS_FILE"
  else
    log "No ingress.yaml found; skipping ingress resource apply."
  fi
}

post_info() {
  log "Cluster nodes:"
  kubectl get nodes -o wide || true
  log "Pods (all namespaces):"
  kubectl get pods -A || true
  log "Services:"
  kubectl get svc -A || true
  log "Ingress resources:"
  kubectl get ingress -A || true

  echo
  cat <<EOF
NEXT STEPS (manual):
1) If you plan to use Ingress and want to access via myapp.local on Windows,
   add this line to your Windows hosts file (run Notepad as Administrator):
     127.0.0.1    myapp.local

2) If ingress isn't ready or you prefer quick test, you can port-forward:
   sudo kubectl port-forward svc/myapp-service 8081:80 > portforward.log 2>&1 &

3) Access the app:
   - via ingress (after hosts entry): http://myapp.local
   - or via port-forward: http://localhost:8081

EOF
}

# ----- main -----
ensure_root
check_docker

# ensure required files
ensure_file "$DEPLOYMENT_FILE"
ensure_file "$SERVICE_FILE"

# create cluster (assumes create-cluster-with-env.sh exists and handles .env)
if [ -f "$CLUSTER_SCRIPT" ]; then
  run_create_cluster || { err "Cluster creation failed."; exit 1; }
else
  log "Cluster script not found. Checking if 'kind' cluster exists." 
  if ! command -v kind >/dev/null 2>&1; then
    err "kind CLI not found. Install kind or provide create-cluster-with-env.sh in the directory."
    exit 1
  fi
fi

# wait for nodes ready
log "Waiting for all nodes to be Ready (120s)..."
if ! kubectl wait --for=condition=Ready nodes --all --timeout=120s; then
  err "Not all nodes became Ready in time. Show nodes and kube-system pods:"
  kubectl get nodes -o wide || true
  kubectl get pods -n kube-system -o wide || true
  exit 1
fi

apply_manifests

# install ingress controller (stable manifest for kind)
install_ingress_controller || { err "Ingress installation encountered issues."; }

apply_ingress_resource

post_info

log "install.sh finished."
