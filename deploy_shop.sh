#!/usr/bin/env bash
# Script de déploiement complet - 1 clic

set -e

echo "🚀 DÉPLOIEMENT COMPLET MASLIVE"
echo "==============================="
echo ""

# Message de commit par défaut
COMMIT_MSG="${1:-feat: amélioration shop et admin}"

echo "📝 [1/5] Stage des fichiers..."
git add .vscode/tasks.json
git add app/lib/models/cart_item.dart
git add app/lib/models/product_model.dart
git add app/lib/services/cart_service.dart
git add app/lib/pages/cart_page.dart
git add app/lib/pages/product_detail_page.dart
git add app/lib/admin/admin_main_dashboard.dart
git add app/pubspec.yaml
git add app/assets/images/*.svg 2>/dev/null || true
git add app/assets/shop/* 2>/dev/null || true

echo "✅ Fichiers stagés"
echo ""

echo "📦 [2/5] Commit..."
if git diff --cached --quiet; then
  echo "ℹ️  Aucune modification à commiter"
else
  git commit -m "$COMMIT_MSG"
  echo "✅ Commit effectué"
fi
echo ""

echo "🔄 [3/5] Push vers GitHub..."
BRANCH=$(git branch --show-current)
git push origin "$BRANCH"
echo "✅ Push terminé"
echo ""

echo "🔧 [4/5] Build Flutter Web..."
cd app
flutter pub get
flutter build web --release --no-wasm-dry-run
cd ..
echo "✅ Build terminé"
echo ""

echo "🚀 [5/5] Deploy Firebase..."
firebase deploy --only hosting
echo "✅ Deploy terminé"
echo ""

echo "════════════════════════════"
echo "✅ DÉPLOIEMENT TERMINÉ !"
echo "════════════════════════════"
echo ""
echo "🌐 App disponible sur Firebase Hosting"
