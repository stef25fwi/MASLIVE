#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/MASLIVE/app
flutter pub get

echo "🔨 Building Flutter Web..."
flutter build web --release

cd /workspaces/MASLIVE
echo "🚀 Deploying to Firebase..."
firebase deploy --only firestore:rules,functions,hosting

echo "✅ Déploiement complet terminé (Firestore + Functions + Web)"
