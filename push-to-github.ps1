# ============================================================
# Push all 6 services to individual GitHub repositories
# Run from: c:\Users\numaa\Desktop\ecom-raw-code\
# Usage:    .\push-to-github.ps1
# ============================================================

$ErrorActionPreference = "Stop"

$services = @(
    @{ folder = "api-gateway";       repo = "ecom-api-gateway" },
    @{ folder = "product-service";   repo = "ecom-product-service" },
    @{ folder = "order-service";     repo = "ecom-order-service" },
    @{ folder = "payment-service";   repo = "ecom-payment-service" },
    @{ folder = "inventory-service"; repo = "ecom-inventory-service" },
    @{ folder = "email-service";     repo = "ecom-email-service" }
)

$root = $PSScriptRoot

foreach ($svc in $services) {
    $path = Join-Path $root $svc.folder
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  $($svc.folder)  ->  $($svc.repo)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    Set-Location $path

    # Create GitHub repo (skip if it already exists)
    Write-Host "Creating GitHub repo..." -ForegroundColor Yellow
    gh repo create $svc.repo --public --description "Ecom microservice: $($svc.folder)" 2>&1 | ForEach-Object {
        if ($_ -match "already exists") {
            Write-Host "  Repo already exists, skipping creation." -ForegroundColor DarkYellow
        } else {
            Write-Host "  $_"
        }
    }

    # Init git if not already a repo
    if (-not (Test-Path ".git")) {
        Write-Host "Initialising git..." -ForegroundColor Yellow
        git init
        git branch -M main
    } else {
        Write-Host "Git already initialised." -ForegroundColor DarkYellow
    }

    # Stage all files
    Write-Host "Staging files..." -ForegroundColor Yellow
    git add .

    # Commit (skip if nothing to commit)
    $status = git status --porcelain
    if ($status) {
        git commit -m "initial commit"
    } else {
        Write-Host "  Nothing to commit." -ForegroundColor DarkYellow
    }

    # Set remote (replace if it already exists)
    $remoteUrl = "https://github.com/numaanmkfullstack-jpg/$($svc.repo).git"
    $existingRemote = git remote 2>&1
    if ($existingRemote -match "origin") {
        git remote set-url origin $remoteUrl
    } else {
        git remote add origin $remoteUrl
    }

    # Push
    Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
    git push -u origin main

    Write-Host "  Done: https://github.com/numaanmkfullstack-jpg/$($svc.repo)" -ForegroundColor Green
}

Set-Location $root

# ============================================================
# Push the full codebase as ecom-full-code
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  full codebase  ->  ecom-full-code" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "Creating GitHub repo..." -ForegroundColor Yellow
gh repo create "ecom-full-code" --public --description "Full ecom microservices codebase" 2>&1 | ForEach-Object {
    if ($_ -match "already exists") {
        Write-Host "  Repo already exists, skipping creation." -ForegroundColor DarkYellow
    } else {
        Write-Host "  $_"
    }
}

if (-not (Test-Path ".git")) {
    Write-Host "Initialising git..." -ForegroundColor Yellow
    git init
    git branch -M main
} else {
    Write-Host "Git already initialised." -ForegroundColor DarkYellow
}

Write-Host "Staging files..." -ForegroundColor Yellow
git add .

$status = git status --porcelain
if ($status) {
    git commit -m "initial commit"
} else {
    Write-Host "  Nothing to commit." -ForegroundColor DarkYellow
}

$remoteUrl = "https://github.com/numaanmkfullstack-jpg/ecom-full-code.git"
$existingRemote = git remote 2>&1
if ($existingRemote -match "origin") {
    git remote set-url origin $remoteUrl
} else {
    git remote add origin $remoteUrl
}

git push -u origin main
Write-Host "  Done: https://github.com/numaanmkfullstack-jpg/ecom-full-code" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  All repos pushed successfully!" -ForegroundColor Green
Write-Host "  Full code: https://github.com/numaanmkfullstack-jpg/ecom-full-code" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
