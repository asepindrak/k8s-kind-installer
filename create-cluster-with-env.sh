#!/usr/bin/env bash
# create-cluster-with-env.sh
# Create a kind cluster using a .env file to set WORKER_COUNT and CLUSTER_NAME.
# Behavior: if cluster exists, will warn and delete it before recreating with new worker count.
set -euo pipefail
IFS=$'\n\t'

# Load .env if present (export values)
if [ -f ".env" ]; then
  # shellcheck disable=SC1091
  set -a
  . ./.env
  set +a
else
  echo "[kind-env] Warning: .env not found in current directory. Using defaults."
fi

: "${CLUSTER_NAME:=k8s-cluster}"
: "${WORKER_COUNT:=2}"
: "${KIND_VERSION:=v0.20.0}"
: "${KUBECTL_VERSION:=}"

KIND_BIN="/usr/local/bin/kind"
KUBECTL_BIN="/usr/local/bin/kubectl"
CONFIG_FILE="${CLUSTER_NAME}-kind-config.yaml"
WAIT_TIMEOUT="180s"

log() { printf '\033[1;32m[kind-env]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[kind-env]\033[0m %s\n' "$*" >&2; }

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    err "docker not found."
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    err "Docker daemon unreachable. Start Docker Desktop."
    exit 1
  fi
  log "Docker available."
}

install_kind_if_missing() {
  if command -v kind >/dev/null 2>&1; then
    log "kind present: $(kind --version 2>/dev/null || echo 'unknown')"
    return
  fi
  log "Installing kind ${KIND_VERSION}..."
  curl -fsSL "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" -o /tmp/kind
  chmod +x /tmp/kind
  sudo mv /tmp/kind "${KIND_BIN}"
  log "kind installed at ${KIND_BIN}"
}

install_kubectl_if_missing() {
  if command -v kubectl >/dev/null 2>&1; then
    log "kubectl present: $(kubectl version --client --short 2>/dev/null || echo 'unknown')"
    return
  fi
  if [ -n "${KUBECTL_VERSION}" ]; then
    RELEASE="${KUBECTL_VERSION}"
  else
    RELEASE="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  fi
  log "Installing kubectl ${RELEASE}..."
  curl -fsSL "https://dl.k8s.io/release/${RELEASE}/bin/linux/amd64/kubectl" -o /tmp/kubectl
  chmod +x /tmp/kubectl
  sudo mv /tmp/kubectl "${KUBECTL_BIN}"
  log "kubectl installed at ${KUBECTL_BIN}"
}

generate_kind_config() {
  # always create a single control-plane + WORKER_COUNT workers
  cat > "${CONFIG_FILE}" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
EOF

  # append workers
  i=1
  while [ "$i" -le "$WORKER_COUNT" ]; do
    cat >> "${CONFIG_FILE}" <<EOF
  - role: worker
EOF
    i=$((i+1))
  done

  log "Generated kind config (${CONFIG_FILE}) with ${WORKER_COUNT} worker(s)."
}

cluster_exists() {
  if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}\$"; then
    return 0
  fi
  return 1
}

delete_cluster_if_exists() {
  if cluster_exists; then
    log "Cluster '${CLUSTER_NAME}' already exists."
    echo
    echo "WARNING: The existing cluster will be deleted and recreated with ${WORKER_COUNT} worker(s)."
    echo "All workloads on the existing cluster will be lost."
    read -r -p "Type 'yes' to proceed and delete cluster '${CLUSTER_NAME}': " confirm
    if [ "$confirm" != "yes" ]; then
      err "Aborting as user did not confirm cluster deletion."
      exit 1
    fi
    log "Deleting existing cluster '${CLUSTER_NAME}'..."
    kind delete cluster --name "${CLUSTER_NAME}"
    log "Cluster deleted."
  fi
}

create_cluster() {
  log "Creating cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_FILE}"
  log "Cluster create command finished."
}

wait_nodes_ready() {
  log "Waiting for nodes to become Ready (timeout ${WAIT_TIMEOUT})..."
  if ! kubectl wait --for=condition=Ready nodes --all --timeout="${WAIT_TIMEOUT}" >/dev/null 2>&1; then
    err "Nodes did not become Ready within ${WAIT_TIMEOUT}."
    kubectl get nodes -o wide || true
    kubectl get pods -A || true
    exit 1
  fi
  log "All nodes Ready."
  kubectl get nodes -o wide
}

main() {
  require_docker
  install_kind_if_missing
  install_kubectl_if_missing
  # sanitize WORKER_COUNT
  if ! [[ "${WORKER_COUNT}" =~ ^[0-9]+$ ]]; then
    err "WORKER_COUNT must be an integer >= 0. Current: ${WORKER_COUNT}"
    exit 1
  fi

  generate_kind_config

  if cluster_exists; then
    delete_cluster_if_exists
  fi

  create_cluster
  wait_nodes_ready

  log "Cluster '${CLUSTER_NAME}' with ${WORKER_COUNT} worker(s) is ready."
  log "Config file: ${CONFIG_FILE}"
  log "To delete: kind delete cluster --name ${CLUSTER_NAME}"
}

main "$@"
