#!/bin/bash
# Apply ArgoCD config on APP VM (run after ArgoCD + Image Updater are installed)
# Run WITHOUT sudo
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== ArgoCD Image Updater config ==="
kubectl apply -f image-updater-config.yaml

echo "=== ArgoCD ingress ==="
kubectl apply -f argocd-ingress.yaml

echo "=== ArgoCD Application (staging) ==="
kubectl apply -f application-ecom-staging.yaml
kubectl delete application ecom -n argocd --ignore-not-found

echo ""
echo "Done. Get ArgoCD password:"
echo "  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "Open: http://argocd.devops.local  (add to Windows hosts file)"
