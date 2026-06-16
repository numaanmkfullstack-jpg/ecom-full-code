#!/bin/bash
# ============================================================
# Staging + Prod environment setup checklist
# Run sections on the correct VM as labeled
# ============================================================

cat <<'EOF'

╔══════════════════════════════════════════════════════════════╗
║  STAGING + PROD SETUP                                        ║
╚══════════════════════════════════════════════════════════════╝

FLOW
────
  push to stage  → Jenkins auto-builds :staging → staging APP VM (Argo CD)
  merge to main  → Jenkins waits for Approve → :prod → prod APP VM (Argo CD)

VMs
───
  Staging APP VM : 192.168.56.10  (your current VM)
  Prod APP VM    : 192.168.56.12  (clone of staging)
  DevOps VM      : Jenkins + monitoring (one VM, both pipelines)

══════════════════════════════════════════════════════════════
STEP 1 — VirtualBox: clone prod APP VM
══════════════════════════════════════════════════════════════
  1. Shut down staging APP VM
  2. Right-click VM → Clone → Full clone → name: app-prod-vm
  3. Prod VM Settings → Network → Host-only adapter → set static IP 192.168.56.12
  4. Boot prod VM, set hostname: sudo hostnamectl set-hostname app-prod-vm

══════════════════════════════════════════════════════════════
STEP 2 — GitHub: push ecom-full-code + service repos
══════════════════════════════════════════════════════════════
  Push k8s changes (apps-prod, argocd apps, Jenkinsfiles) from Windows.

  In EACH of the 7 service repos create stage branch:
    git checkout -b stage
    git push -u origin stage

══════════════════════════════════════════════════════════════
STEP 3 — Jenkins (DevOps VM): Multibranch pipelines
══════════════════════════════════════════════════════════════
  For each service job:
    1. New Item → Multibranch Pipeline
    2. Branch Sources → Git → repo URL
    3. Discover branches: stage + main
    4. Build configuration → by Jenkinsfile
    5. Scan repo now

  stage branch : auto build + push :staging (no approval)
  main branch  : pauses at "Approve Prod Deploy" → click Approve → :prod

══════════════════════════════════════════════════════════════
STEP 4 — Staging APP VM (current)
══════════════════════════════════════════════════════════════
  cd ~/ecom-full-code/k8s/argocd   # or your k8s path
  bash apply-argocd-staging.sh

  kubectl get application ecom-staging -n argocd

  URLs (existing):
    ui.devops.local
    api.devops.local

══════════════════════════════════════════════════════════════
STEP 5 — Prod APP VM (clone)
══════════════════════════════════════════════════════════════
  cd ~/ecom-full-code/k8s
  bash apply-prod.sh

  cd argocd
  bash apply-argocd-prod.sh

  kubectl get application ecom-prod -n argocd

══════════════════════════════════════════════════════════════
STEP 6 — Windows hosts + port forwards
══════════════════════════════════════════════════════════════
  C:\Windows\System32\drivers\etc\hosts

  Staging (port forward 80 → staging APP VM):
    127.0.0.1  ui.devops.local
    127.0.0.1  api.devops.local

  Prod (port forward 8081 → prod APP VM:80):
    127.0.0.1  ui-prod.devops.local
    127.0.0.1  api-prod.devops.local

══════════════════════════════════════════════════════════════
STEP 7 — Test the pipeline
══════════════════════════════════════════════════════════════
  A) Staging (auto):
     git checkout stage && git push
     → Jenkins builds :staging
     → Argo CD staging rolls out within ~2 min

  B) Prod (manual approval):
     PR stage → main, merge
     → Jenkins main build starts
     → Click "Approve" in Jenkins UI
     → pushes :prod
     → Argo CD prod rolls out

EOF
