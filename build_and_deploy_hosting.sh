#!/bin/bash

# Build web Flutter + Deploy hosting Firebase uniquement

set -e

echo "🚀 Build Flutter Web + Deploy Hosting"
echo "====================================="

cd /workspaces/MASLIVE

echo ""
echo "📱 Étape 1: Build Flutter Web..."
cd app
{ [ -f /workspaces/MASLIVE/.env ] && source /workspaces/MASLIVE/.env; } 2>/dev/null || true
TOKEN=${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}}
if [ -z "$TOKEN" ]; then
	echo "❌ ERREUR: token Mapbox manquant (MAPBOX_ACCESS_TOKEN / MAPBOX_PUBLIC_TOKEN / MAPBOX_TOKEN)."
	echo "➡️  Lance la tâche: MASLIVE: 🗺️ Set Mapbox token (.env) puis relance."
	exit 1
fi
echo "🗺️  Token Mapbox détecté: ${TOKEN:0:15}..."
flutter build web --release --no-wasm-dry-run --dart-define=MAPBOX_ACCESS_TOKEN="$TOKEN"
cd ..

echo ""
echo "✅ Build terminé"

echo ""
echo "🌐 Étape 2: Deploy Hosting Firebase..."
firebase deploy --only hosting

echo ""
echo "✅ Déploiement réussi !"
echo ""
echo "🎉 App live : https://maslive.web.app"
