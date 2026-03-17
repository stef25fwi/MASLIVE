#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/MASLIVE

echo "🔧 Menu burger Storex: fix texte + bas gris"
echo "==========================================="

# Git setup
git config --local user.email "devcontainer@maslive.local" 2>/dev/null || true
git config --local user.name "MASLIVE Devcontainer" 2>/dev/null || true
git config --local commit.gpgsign false 2>/dev/null || true

# Stage + Commit
echo "[1/3] Staging..."
git add -A
git status --short

if ! git diff --cached --quiet; then
  echo "[2/3] Committing..."
  git commit -m "fix(shop-drawer): change 'Marché des médias' to 'La boutique photo' + remove gray bottom spacing"
else
  echo "[2/3] No changes to commit"
fi

# Push
echo "[3/3] Pushing..."
git push origin main

echo ""
echo "✅ Commit + Push OK"
echo "   - Menu burger text updated: 'La boutique photo'"
echo "   - Fixed gray area at bottom of menu (removed Spacer)"
