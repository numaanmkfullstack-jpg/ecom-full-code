#!/bin/bash
# Apply Argo CD on STAGING APP VM (current preprod VM)
# Run WITHOUT sudo
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Image Updater config ==="
kubectl apply -f image-updater-config.yaml

echo "=== Staging Argo CD Application (ecom-staging) ==="
kubectl apply -f application-ecom-staging.yaml

# Remove old single-env app if it exists
kubectl delete application ecom -n argocd --ignore-not-found

echo ""
echo "Staging CD ready. Image Updater watches :staging tags from Jenkins stage branch."
echo "  kubectl get application ecom-staging -n argocd"
