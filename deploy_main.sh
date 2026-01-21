#!/bin/bash
# Script de déploiement étape par étape sur main

set -e  # Arrêter à la première erreur

echo "🚀 DÉPLOIEMENT VERS MAIN"
echo "======================="
echo ""

# Étape 1: Stage les fichiers
echo "[1/7] 📝 Stage des fichiers..."
git add -A
echo "✅ Fichiers stagés"
echo ""

# Étape 2: Commit
echo "[2/7] 📦 Commit..."
git commit -m "Feat: Add map presets system with superadmin permissions

- MapPresetModel & LayerModel for map data
- MapPresetsService with full CRUD operations
- MapSelectorPage with dual-mode UI (edit/read-only)
- Permission-based access control for superadmins
- Enhanced permission_service.dart
- Supporting services: GalleryCountsService, RouteValidator, DraftManager
- Updated circuit and media gallery pages
- Complete documentation and implementation guides"
echo "✅ Commit créé"
echo ""

# Étape 3: Push sur V2
echo "[3/7] 🔄 Push V2 → origin/V2..."
git push origin V2
echo "✅ Pushé sur V2"
echo ""

# Étape 4: Merge et push sur main
echo "[4/7] 🔀 Merge V2 → main et push..."
git checkout main
git pull origin main
git merge V2 -m "Merge branch 'V2' into main"
git push origin main
echo "✅ Merged et pushé sur main"
echo ""

# Étape 5: Retour sur V2
echo "[5/7] ↩️  Retour sur V2..."
git checkout V2
echo "✅ Sur V2"
echo ""

# Étape 6: Build web
echo "[6/7] 🏗️  Build Flutter web..."
cd app
flutter pub get
flutter build web --release
cd ..
echo "✅ Build complété"
echo ""

# Étape 7: Deploy Firebase
echo "[7/7] 🌍 Deploy Firebase..."
firebase deploy --only hosting,functions,firestore:rules
echo "✅ Deploy complété (hosting + functions + firestore rules)"
echo ""

echo "════════════════════════════════════════════════"
echo "🎉 DÉPLOIEMENT RÉUSSI!"
echo "════════════════════════════════════════════════"
