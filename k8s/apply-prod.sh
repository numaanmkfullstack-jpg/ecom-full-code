#!/bin/bash
# First-time deploy on PROD APP VM (after cloning staging VM)
# Run WITHOUT sudo: bash apply-prod.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Namespace, secrets, config ==="
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-secrets.yaml
kubectl apply -f 02-configmap.yaml
kubectl apply -f 03-postgres-init-configmap.yaml

echo "=== Infrastructure ==="
kubectl apply -f infra/

echo "=== Waiting for infra ==="
kubectl wait --for=condition=ready pod -l app=postgres  -n ecom --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=mongodb   -n ecom --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=redis     -n ecom --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=rabbitmq  -n ecom --timeout=180s || true

echo "=== Prod apps (Kustomize) ==="
kubectl apply -k apps-prod/

echo "=== Prod ingress ==="
kubectl apply -f ingress-prod.yaml

echo ""
echo "Prod stack applied. DNS on Windows hosts file:"
echo "  <prod-vm-ip-or-port-forward>  ui-prod.devops.local"
echo "  <prod-vm-ip-or-port-forward>  api-prod.devops.local"
