#!/bin/bash
# Déploiement rapide (commit + push + merge) sans build

set -e

echo "⚡ DÉPLOIEMENT RAPIDE (sans build)"
echo "===================================="
echo ""

# Stage
echo "[1/5] 📝 Stage..."
git add -A
echo "✅"
echo ""

# Commit
echo "[2/5] 📦 Commit..."
git commit -m "Feat: Add map presets system with superadmin permissions - Complete implementation"
echo "✅"
echo ""

# Push V2
echo "[3/5] 🔄 Push V2..."
git push origin V2
echo "✅"
echo ""

# Merge main
echo "[4/5] 🔀 Merge main..."
git checkout main
git pull origin main
git merge V2 --no-edit
git push origin main
echo "✅"
echo ""

# Retour V2
echo "[5/5] ↩️  Retour V2..."
git checkout V2
echo "✅"
echo ""

echo "════════════════════════════"
echo "✅ PUSH VERS MAIN RÉUSSI!"
echo "════════════════════════════"
