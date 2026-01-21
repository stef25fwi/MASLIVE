#!/bin/bash
# Commit + Push + Merge vers main (sans Firebase)

set -e

echo "📤 COMMIT & PUSH VERS MAIN"
echo "=========================="
echo ""

# Stage
echo "[1/4] 📝 Stage des fichiers..."
git add -A
echo "✅ Stagés"
echo ""

# Commit
echo "[2/4] 📦 Commit..."
git commit -m "Feat: Add map presets system with superadmin permissions

- MapPresetModel & LayerModel for map data structures
- MapPresetsService with full CRUD operations
- MapSelectorPage with dual-mode UI (edit/read-only)
- Permission-based access control for superadmins
- Enhanced permission_service.dart
- Supporting services: GalleryCountsService, RouteValidator, DraftManager
- Updated circuit and media gallery pages
- Complete documentation and implementation guides"
echo "✅ Committés"
echo ""

# Push V2
echo "[3/4] 🔄 Push V2 → origin..."
git push origin V2
echo "✅ V2 pushée"
echo ""

# Merge main
echo "[4/4] 🔀 Merge & push main..."
git checkout main
git pull origin main
git merge V2 --no-edit
git push origin main
git checkout V2
echo "✅ Main pushée"
echo ""

echo "════════════════════════════"
echo "✅ CODE DÉPLOYÉ SUR MAIN!"
echo "════════════════════════════"
echo ""
echo "📝 Prochaine étape (optionnel):"
echo "   bash deploy_firebase.sh"
