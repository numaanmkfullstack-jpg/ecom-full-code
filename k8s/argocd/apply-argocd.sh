#!/bin/bash
# Apply ArgoCD config on APP VM (run after ArgoCD + Image Updater are installed)
set -e

echo "=== ArgoCD Image Updater config ==="
kubectl apply -f image-updater-config.yaml

echo "=== ArgoCD ingress ==="
kubectl apply -f argocd-ingress.yaml

echo "=== ArgoCD Application ==="
kubectl apply -f application-ecom.yaml

echo ""
echo "Done. Get ArgoCD password:"
echo "  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "Open: http://argocd.devops.local  (add to Windows hosts file)"
