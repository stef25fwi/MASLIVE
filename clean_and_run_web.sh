#!/bin/bash
set -e

echo "🧹 Arrêt de Flutter..."
pkill -9 -f "flutter" 2>/dev/null || true
pkill -9 -f "dart" 2>/dev/null || true
sleep 1

echo "🗑️  Suppression du cache..."
cd /workspaces/MASLIVE/app
rm -rf build/
rm -rf .dart_tool/
rm -rf .flutter-plugins
rm -rf .flutter-plugins-dependencies

echo "📦 flutter pub get..."
flutter pub get

echo ""
echo "🚀 Lancement de l'app web avec Mapbox GL JS..."
echo "   → HomeWebPage sera utilisée sur le web"
echo "   → Carte Mapbox GL JS avec token via --dart-define"
echo ""

if [ -z "$MAPBOX_ACCESS_TOKEN" ]; then
  echo "❌ MAPBOX_ACCESS_TOKEN non défini"
  exit 1
fi

flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 8080 \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
