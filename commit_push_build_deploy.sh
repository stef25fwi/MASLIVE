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
git commit -m "feat: UI improvements

- Move header to bottom bar on home page
- Make status bar transparent with dark icons
- Redesign shop page header with gradient and search pill
- Remove white padding on shop grid
"
echo "✅ Committés"
echo ""

# Push V2
echo "[3/5] 🔄 Push V2 → origin..."
git push origin V2
echo "✅ V2 pushée"
echo ""

# Merge main
echo "[4/5] 🔀 Merge & push main..."
git checkout main
git pull origin main
git merge V2 --no-edit
git push origin main
git checkout V2
echo "✅ Main pushée"
echo ""

# Build & Deploy
echo "[5/5] 🚀 Build & Deploy..."
cd app
flutter build web --release
cd ..
firebase deploy --only hosting
echo "✅ Déployé"
echo ""

echo "════════════════════════════"
echo "✅ CODE DÉPLOYÉ SUR MAIN!"
echo "════════════════════════════"
