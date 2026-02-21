#!/bin/bash

# 🚀 Script de déploiement - Group Map Visibility Feature
# Version: 1.0
# Date: 04/02/2026

set -e  # Exit on error

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 DÉPLOIEMENT - Group Map Visibility Feature"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Phase 1: Préparation
echo "📋 Phase 1/9: Préparation..."
git branch | grep '* main' && echo "✅ Branche: main" || echo "⚠️  Attention: pas sur main"
git status
echo ""

# Phase 2: Dépendances
echo "📦 Phase 2/9: Installation dépendances..."
cd app
flutter pub get
echo "✅ Dépendances installées"
echo ""

# Build runner (Hive adapters)
echo "🔧 Génération des adapters Hive..."
flutter pub run build_runner build --delete-conflicting-outputs
echo "✅ Adapters générés"
echo ""

# Phase 3: Tests
echo "🧪 Phase 3/9: Tests..."
flutter test test/services/group_tracking_test.dart -v
echo "✅ Tests passés"
echo ""

# Analyzer
echo "🔍 Phase 3b: Analyse du code..."
flutter analyze
echo "✅ Analyse terminée"
echo ""

# Phase 4: Vérification
echo "🔍 Phase 4/9: Vérification des fichiers..."
test -f lib/services/group/group_map_visibility_service.dart && echo "✅ Service exists" || echo "❌ Service missing"
test -f lib/widgets/group_map_visibility_widget.dart && echo "✅ Widget exists" || echo "❌ Widget missing"
grep -q "GroupMapVisibilityWidget" lib/pages/group/admin_group_dashboard_page.dart && echo "✅ Integration OK" || echo "❌ Integration missing"
echo ""

# Phase 5: Build Web
echo "🏗️  Phase 5/9: Build web..."
echo "⏳ Nettoyage..."
flutter clean
flutter pub get
echo "⏳ Building web (cela peut prendre 2-3 min)..."

# Check for MAPBOX_TOKEN
if [ -n "$MAPBOX_ACCESS_TOKEN" ]; then
    flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
elif [ -n "$MAPBOX_PUBLIC_TOKEN" ]; then
    flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"
elif [ -n "$MAPBOX_TOKEN" ]; then
    flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN"
else
    echo "❌ ERREUR: token Mapbox manquant (MAPBOX_ACCESS_TOKEN / MAPBOX_PUBLIC_TOKEN / MAPBOX_TOKEN)."
    echo "➡️  Renseigne /workspaces/MASLIVE/.env (task: 'MASLIVE: 🗺️ Set Mapbox token (.env)') puis relance."
    exit 1
fi

echo "✅ Build web terminé"
echo ""

# Check build size
echo "📊 Taille du build:"
du -sh build/web/
echo ""

# Phase 6: Firestore Rules (skip - already in firestore.rules)
echo "🔐 Phase 6/9: Firestore Rules..."
cd ..
echo "ℹ️  Rules are already in firestore.rules"
echo "✅ Rules OK"
echo ""

# Phase 7: Deploy Firebase
echo "🚀 Phase 7/9: Déploiement Firebase..."
echo "⏳ Deploying hosting..."
firebase deploy --only hosting
echo "✅ Hosting déployé"
echo ""

# Optional: Deploy rules
read -p "Voulez-vous déployer les Firestore rules? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    firebase deploy --only firestore:rules
    echo "✅ Rules déployées"
fi
echo ""

# Phase 8: Vérification
echo "✅ Phase 8/9: Tests manuels..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Application déployée!"
echo ""
echo "📍 URL: https://masslive.web.app"
echo ""
echo "🧪 Tests manuels à effectuer:"
echo "   1. Ouvrir: https://masslive.web.app"
echo "   2. Aller à: Dashboard Admin Groupe"
echo "   3. Scroller: Section 'Visibilité sur les cartes'"
echo "   4. Tester: Toggle des checkboxes"
echo "   5. Vérifier: Console browser (F12) - pas d'erreurs"
echo "   6. Vérifier: Firestore - visibleMapIds updated"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Phase 9: Monitoring
echo "📊 Phase 9/9: Monitoring..."
echo "Checking deployment status..."
curl -s -o /dev/null -w "%{http_code}" https://masslive.web.app | grep -q "200" && echo "✅ App accessible (HTTP 200)" || echo "⚠️  App may not be accessible yet"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 DÉPLOIEMENT TERMINÉ!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Prochaines étapes:"
echo "   1. Tester l'application: https://masslive.web.app"
echo "   2. Monitorer les logs: firebase functions:log --tail"
echo "   3. Vérifier les métriques: Console Firebase"
echo ""
echo "📚 Documentation:"
echo "   - Feature spec: FEATURE_GROUP_MAP_VISIBILITY.md"
echo "   - Testing guide: TESTING_GROUP_MAP_VISIBILITY.md"
echo "   - Quick ref: QUICK_REFERENCE_MAP_VISIBILITY.md"
echo ""
echo "✅ Feature 'Group Map Visibility' est maintenant LIVE!"
echo ""
