#!/usr/bin/env bash
set -euo pipefail

echo "Deleting istio-jwt-demo namespace..."
if kubectl get namespace istio-jwt-demo &>/dev/null; then
    kubectl delete namespace istio-jwt-demo --timeout=60s
    echo "Namespace deleted."
else
    echo "Namespace does not exist, skipping."
fi

if [[ "${1:-}" == "--full" ]]; then
    echo "Stopping and deleting minikube..."
    minikube stop 2>/dev/null || true
    minikube delete 2>/dev/null || true
    echo "Done."
else
    echo "minikube still running. Use --full to also delete minikube."
fi
