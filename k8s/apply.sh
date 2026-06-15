#!/bin/bash
# ============================================================
# Deploy the full ecom stack to K3s
# Run on the APP VM after cloning the repo
# Usage: bash apply.sh
# ============================================================

set -e

echo ""
echo "=== Step 1: Namespace, Secrets, ConfigMaps ==="
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-secrets.yaml
kubectl apply -f 02-configmap.yaml
kubectl apply -f 03-postgres-init-configmap.yaml

echo ""
echo "=== Step 2: Infrastructure (Postgres, MongoDB, Redis, RabbitMQ) ==="
kubectl apply -f infra/

echo ""
echo "=== Step 3: Waiting for infrastructure to be ready... ==="
kubectl wait --for=condition=ready pod -l app=postgres  -n ecom --timeout=120s
kubectl wait --for=condition=ready pod -l app=mongodb   -n ecom --timeout=120s
kubectl wait --for=condition=ready pod -l app=redis     -n ecom --timeout=120s
kubectl wait --for=condition=ready pod -l app=rabbitmq  -n ecom --timeout=180s

echo ""
echo "=== Step 4: Application Services ==="
kubectl apply -f apps/

echo ""
echo "=== Step 5: Ingress ==="
kubectl apply -f ingress.yaml

echo ""
echo "=== All done! Waiting for app pods... ==="
kubectl wait --for=condition=ready pod -l app=api-gateway        -n ecom --timeout=120s
kubectl wait --for=condition=ready pod -l app=product-service    -n ecom --timeout=120s
kubectl wait --for=condition=ready pod -l app=order-service      -n ecom --timeout=120s
kubectl wait --for=condition=ready pod -l app=payment-service    -n ecom --timeout=120s
kubectl wait --for=condition=ready pod -l app=inventory-service  -n ecom --timeout=120s
kubectl wait --for=condition=ready pod -l app=email-service      -n ecom --timeout=120s
kubectl wait --for=condition=ready pod -l app=admin-ui           -n ecom --timeout=120s

echo ""
echo "============================================"
echo "  Deployment complete!"
echo "============================================"
kubectl get pods -n ecom
echo ""
echo "Add these to /etc/hosts on your Windows machine:"
echo "  <THIS VM IP>  ui.devops.local"
echo "  <THIS VM IP>  api.devops.local"
