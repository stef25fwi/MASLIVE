#!/bin/bash
# Déploiement Firebase uniquement

set -e

echo "🌍 DÉPLOIEMENT FIREBASE"
echo "======================="
echo ""

# Build web
echo "[1/3] 🏗️  Build Flutter web..."
cd /workspaces/MASLIVE/app
flutter pub get
{ [ -f /workspaces/MASLIVE/.env ] && source /workspaces/MASLIVE/.env; } 2>/dev/null || true
TOKEN=${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}}
if [ -z "$TOKEN" ]; then
	echo "❌ ERREUR: token Mapbox manquant (MAPBOX_ACCESS_TOKEN / MAPBOX_PUBLIC_TOKEN / MAPBOX_TOKEN)."
	echo "➡️  Lance la tâche: MASLIVE: 🗺️ Set Mapbox token (.env) puis relance."
	exit 1
fi
echo "🗺️  Token Mapbox détecté: OK (redacted)"
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$TOKEN"
cd /workspaces/MASLIVE
echo "✅ Build complété"
echo ""

# Deploy Firestore rules
echo "[2/3] 📋 Deploy Firestore rules..."
firebase deploy --only firestore:rules
echo "✅ Firestore rules déployées"
echo ""

# Deploy hosting + functions
echo "[3/3] 🚀 Deploy hosting et functions..."
firebase deploy --only hosting,functions
echo "✅ Hosting et functions déployés"
echo ""

echo "════════════════════════════"
echo "✅ FIREBASE DÉPLOYÉ!"
echo "════════════════════════════"
