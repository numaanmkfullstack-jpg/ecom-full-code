#!/bin/bash
# Apply Argo CD on PROD APP VM (cloned VM, new IP e.g. 192.168.56.12)
# Run WITHOUT sudo
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Image Updater config ==="
kubectl apply -f image-updater-config.yaml

echo "=== Prod Argo CD Application (ecom-prod) ==="
kubectl apply -f application-ecom-prod.yaml

echo ""
echo "Prod CD ready. Image Updater watches :prod tags after Jenkins main + approval."
echo "  kubectl get application ecom-prod -n argocd"
