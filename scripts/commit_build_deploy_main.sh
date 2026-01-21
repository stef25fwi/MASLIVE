#!/bin/bash

# Script pour commit, push, build et déployer vers main
# Usage: bash scripts/commit_build_deploy_main.sh

set -e

echo "════════════════════════════════════════════════"
echo "🔄 COMMIT • PUSH • BUILD • DEPLOY vers MAIN"
echo "════════════════════════════════════════════════"
echo ""

# 1. Vérifier qu'on est sur V2
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "V2" ]; then
  echo "⚠️  Vous êtes sur la branche '$CURRENT_BRANCH', pas sur V2"
  echo "Basculez vers V2: git checkout V2"
  exit 1
fi
echo "✅ Branche actuelle: $CURRENT_BRANCH"
echo ""

# 2. Stage tous les fichiers
echo "📝 Stage des fichiers..."
git add -A
echo "✅ Fichiers staged"
echo ""

# 3. Commit avec message descriptif
echo "📦 Création du commit..."
COMMIT_MSG="Feat: Add map presets system with superadmin permissions

- Implement MapPresetModel and LayerModel data structures
- Add MapPresetsService with full CRUD operations
- Create MapSelectorPage with dual-mode UI (edit/read-only)
- Integrate with HomeMapPage for map selection
- Add permission-based access control (superadmin only)
- Enhanced permission_service with superadmin verification
- Add supporting services: GalleryCountsService, DraftManager, RouteValidator
- Update circuit and media gallery pages
- Complete documentation with MAP_PRESETS_SYSTEM.md and implementation guides"

git commit -m "$COMMIT_MSG"
echo "✅ Commit créé"
echo ""

# 4. Push vers V2
echo "🚀 Push vers V2..."
git push origin V2
echo "✅ Pushed vers V2"
echo ""

# 5. Merge vers main
echo "🔀 Merge V2 → main..."
git checkout main
git pull origin main
git merge V2 -m "Merge branch 'V2' into main"
git push origin main
echo "✅ Merged et pushed vers main"
echo ""

# 6. Retour sur V2
echo "↩️  Retour sur V2..."
git checkout V2
echo "✅ Sur V2"
echo ""

# 7. Build web
echo "🏗️  Build Flutter web..."
cd app
flutter pub get
flutter build web --release
echo "✅ Build complété"
cd ..
echo ""

# 8. Deploy sur Firebase
echo "🌍 Deploy sur Firebase (hosting + functions + rules)..."
firebase deploy --only hosting,functions,firestore:rules,storage:rules
echo "✅ Deploy complété"
echo ""

echo "════════════════════════════════════════════════"
echo "🎉 TOUS LES DÉPLOIEMENTS RÉUSSIS!"
echo "════════════════════════════════════════════════"
echo ""
echo "Résumé:"
echo "  ✅ Commit sur V2"
echo "  ✅ Push V2 → origin/V2"
echo "  ✅ Merge V2 → main"
echo "  ✅ Push main → origin/main"
echo "  ✅ Build web"
echo "  ✅ Deploy Firebase (hosting + functions + rules)"
echo ""
