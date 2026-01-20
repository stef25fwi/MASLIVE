#!/usr/bin/env bash
set -euo pipefail

echo "🔨 Building Flutter Web..."
cd /workspaces/MASLIVE/app
flutter build web --release

echo "🚀 Deploying to Firebase Hosting..."
cd /workspaces/MASLIVE
firebase deploy --only hosting

echo "✅ Déploiement web terminé sur https://maslive.web.app"
