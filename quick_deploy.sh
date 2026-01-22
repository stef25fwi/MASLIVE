#!/bin/bash
# Quick commit, push, build et deploy depuis main

set -e

echo "🚀 COMMIT • PUSH • BUILD • DEPLOY"
echo "=================================="
echo ""

# Stage
echo "[1/4] 📝 Stage..."
git add -A

# Commit
echo "[2/4] 📦 Commit..."
git commit -m "feat: splashscreen avec wom1.png + images par défaut boutique maslivesmall.png + status bar shop

- Splashscreen natif et Flutter utilisent wom1.png
- Splashscreen reste visible jusqu'à chargement carte + GPS
- Images par défaut boutique: maslivesmall.png
- Status bar transparente page shop avec icônes sombres"

# Push
echo "[3/4] 🔄 Push..."
git push origin main

# Build & Deploy
echo "[4/4] 🚀 Build & Deploy..."
cd app
flutter build web --release
cd ..
firebase deploy --only hosting

echo ""
echo "✅ TERMINÉ !"
echo "🌐 https://maslive.web.app"
