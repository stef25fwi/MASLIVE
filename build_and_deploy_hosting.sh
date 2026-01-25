#!/bin/bash

# Build web Flutter + Deploy hosting Firebase uniquement

set -e

echo "🚀 Build Flutter Web + Deploy Hosting"
echo "====================================="

cd /workspaces/MASLIVE

echo ""
echo "📱 Étape 1: Build Flutter Web..."
cd app
flutter build web --release
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
