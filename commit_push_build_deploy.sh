#!/bin/bash
# Commit + Push + Build + Deploy vers main

set -e

echo "📤 COMMIT & PUSH VERS MAIN"
echo "=========================="
echo ""

# Stage
echo "[1/5] 📝 Stage des fichiers..."
git add -A
echo "✅ Stagés"
echo ""

# Commit
echo "[2/5] 📦 Commit..."
git commit -m "feat: splashscreen avec wom1.png + images par défaut boutique maslivesmall.png + status bar shop

- Splashscreen natif et Flutter utilisent wom1.png
- Splashscreen reste visible jusqu'à chargement carte + GPS
- Images par défaut boutique: maslivesmall.png
- Status bar transparente page shop avec icônes sombres
"
echo "✅ Committés"
echo ""

# Push V2
echo "[3/5] 🔄 Push main → origin..."
git push origin main
echo "✅ Main pushée"
echo ""

# Build & Deploy
echo "[4/5] 🚀 Build & Deploy..."
cd app
flutter build web --release
cd ..
firebase deploy --only hosting
echo "✅ Déployé"
echo ""

echo "════════════════════════════"
echo "✅ CODE DÉPLOYÉ SUR MAIN!"
echo "════════════════════════════"
