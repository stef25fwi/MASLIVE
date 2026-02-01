#!/bin/bash
set -e

echo "🧹 Nettoyage des caches Flutter..."
cd /workspaces/MASLIVE/app

# Tuer les processus Flutter en cours
pkill -f "flutter run" || true
pkill -f "dart" || true
sleep 2

# Nettoyer complètement
rm -rf build/
rm -rf .dart_tool/build/
rm -rf .dart_tool/*.dill*

echo "📦 flutter clean..."
flutter clean

echo "📦 flutter pub get..."
flutter pub get

if [ -z "$MAPBOX_ACCESS_TOKEN" ]; then
  echo "❌ MAPBOX_ACCESS_TOKEN non défini"
  exit 1
fi

echo "🚀 Lancement de l'app avec token Mapbox..."
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN" \
  -v
