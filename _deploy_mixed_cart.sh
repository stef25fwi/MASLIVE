#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/MASLIVE

echo "🚀 Deploy: mixed-cart single-payment (merch+media)"
echo "=================================================="

# Configure git
git config --local user.email "devcontainer@maslive.local" || true
git config --local user.name "MASLIVE Devcontainer" || true
git config --local commit.gpgsign false || true

# Add modified files
echo "[1/4] 📝 Staging files..."
git add -A
git status --short

# Commit
if ! git diff --cached --quiet; then
  echo "[2/4] 📦 Committing..."
  git commit -m "feat(checkout): single-payment mixed-cart (merch+media) + ultra premium UI + hero boutique"
else
  echo "[2/4] ℹ️ Nothing to commit, skipping..."
fi

# Push
echo "[3/4] 🔄 Pushing..."
git push origin main

# Deploy (functions only for now)
echo "[4/4] 🚀 Deploying Functions..."
if command -v firebase >/dev/null 2>&1; then
  firebase deploy --only functions
elif command -v npx >/dev/null 2>&1; then
  npx --yes firebase-tools deploy --only functions
else
  echo "❌ firebase or npx not found"
  exit 127
fi

echo ""
echo "✅ DEPLOYMENT COMPLETE"
echo "   → mixed-cart callable deployed"
echo "   → webhook extended for media entitlements"
echo ""
echo "Next: verify Firestore after mixed-cart test payment"
