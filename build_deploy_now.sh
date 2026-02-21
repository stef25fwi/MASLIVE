#!/bin/bash
set -e

echo "📱 Building Flutter web app..."
cd /workspaces/MASLIVE/app
{ [ -f /workspaces/MASLIVE/.env ] && source /workspaces/MASLIVE/.env; } 2>/dev/null || true
TOKEN=${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}}
if [ -z "$TOKEN" ]; then
	echo "❌ ERREUR: token Mapbox manquant (MAPBOX_ACCESS_TOKEN / MAPBOX_PUBLIC_TOKEN / MAPBOX_TOKEN)."
	echo "➡️  Lance la tâche: MASLIVE: 🗺️ Set Mapbox token (.env) puis relance."
	exit 1
fi
echo "🗺️  Token Mapbox détecté: ${TOKEN:0:15}..."
flutter build web --release --no-wasm-dry-run --dart-define=MAPBOX_ACCESS_TOKEN="$TOKEN"

echo "🚀 Deploying to Firebase hosting..."
cd /workspaces/MASLIVE
firebase deploy --only hosting

echo "✅ Build and deploy completed!"
