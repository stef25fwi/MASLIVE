#!/bin/bash

set -e

echo "╔════════════════════════════════════════════════╗"
echo "║  🚀 Clean + Build + Deploy                     ║"
echo "╚════════════════════════════════════════════════╝"

cd /workspaces/MASLIVE/app

echo ""
echo "🧹 Nettoyage du cache Flutter..."
flutter clean

echo ""
echo "📦 Récupération des dépendances..."
flutter pub get

echo ""
echo "🔨 Building web with Mapbox token..."
TOKEN=${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}}
if [ -n "$TOKEN" ]; then
  echo "🗺️  Token detected: ${TOKEN:0:20}..."
  flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$TOKEN"
else
  echo "❌ ERREUR: token Mapbox manquant (MAPBOX_ACCESS_TOKEN / MAPBOX_PUBLIC_TOKEN / MAPBOX_TOKEN)."
  echo "➡️  Renseigne /workspaces/MASLIVE/.env (task: 'MASLIVE: 🗺️ Set Mapbox token (.env)') puis relance."
  exit 1
fi

echo ""
echo "🚀 Déploiement Firebase Hosting..."
cd ..
firebase deploy --only hosting

echo ""
echo "✅ Déploiement terminé!"
