#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
K8S_DIR="$PROJECT_DIR/k8s"
KEYS_DIR="$PROJECT_DIR/keys"

kubectl apply -f "$K8S_DIR/namespace.yaml"

if [[ ! -f "$KEYS_DIR/jwks.json" ]]; then
    echo "ERROR: jwks.json not found. Run generate-keys.sh first." >&2
    exit 1
fi
kubectl create configmap jwks-config \
    --from-file=jwks.json="$KEYS_DIR/jwks.json" \
    -n istio-jwt-demo \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$K8S_DIR/jwks-deployment.yaml"
kubectl apply -f "$K8S_DIR/jwks-service.yaml"
kubectl apply -f "$K8S_DIR/backend-deployment.yaml"
kubectl apply -f "$K8S_DIR/backend-service.yaml"
kubectl apply -f "$K8S_DIR/istio-gateway.yaml"
kubectl apply -f "$K8S_DIR/istio-virtualservice.yaml"
kubectl apply -f "$K8S_DIR/istio-request-authentication.yaml"
kubectl apply -f "$K8S_DIR/istio-authorization-policy.yaml"

echo "Deployed."
