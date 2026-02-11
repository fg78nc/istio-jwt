#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Starting minikube..."
if minikube status --format='{{.Host}}' 2>/dev/null | grep -q "Running"; then
    echo "minikube is already running."
else
    minikube delete 2>/dev/null || true
    minikube start \
        --memory=4096 \
        --cpus=2 \
        --kubernetes-version=v1.35.0
fi

echo "Configuring containerd to skip TLS verification..."
minikube ssh -- "sudo mkdir -p /etc/containerd/certs.d/docker.io && \
echo 'server = \"https://registry-1.docker.io\"
[host.\"https://registry-1.docker.io\"]
  skip_verify = true' | sudo tee /etc/containerd/certs.d/docker.io/hosts.toml > /dev/null && \
sudo systemctl restart containerd"

echo "Installing Istio (demo profile)..."
if kubectl get namespace istio-system &>/dev/null; then
    if kubectl get deployment istiod -n istio-system &>/dev/null; then
        echo "Istio is already installed."
    else
        istioctl install --set profile=demo -y
    fi
else
    istioctl install --set profile=demo -y
fi

echo "Waiting for Istio to be ready..."
kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=120s
kubectl wait --for=condition=available deployment/istio-ingressgateway -n istio-system --timeout=120s

echo "Generating RSA keys and JWKS..."
bash "$SCRIPT_DIR/generate-keys.sh"

echo "Building Docker images..."
cd "$PROJECT_DIR"
mvn clean package -DskipTests -q
docker build -t istio-jwt-backend:latest .
docker build -t jwks-server:latest "$PROJECT_DIR/jwks-server/"

echo "Loading images into minikube..."
minikube image load istio-jwt-backend:latest
minikube image load jwks-server:latest

echo "Deploying to Kubernetes..."
bash "$SCRIPT_DIR/deploy.sh"

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=backend -n istio-jwt-demo --timeout=120s
kubectl wait --for=condition=ready pod -l app=jwks-server -n istio-jwt-demo --timeout=120s

echo "Setup complete. Next steps:"
echo "  minikube tunnel                  # in a separate terminal, requires sudo"
echo "  curl http://127.0.0.1/api/public # test"
echo "  ./scripts/test.sh               # run all tests"
