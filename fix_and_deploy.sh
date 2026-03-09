#!/bin/bash
set -e

cd /workspaces/MASLIVE

echo "📝 Git add..."
git add app/lib/pages/default_map_page.dart app/lib/ui/map/maslive_map_web.dart

echo "📝 Git commit..."
git commit -m "fix(web-map): repair home map container sizing"

echo "📤 Git push..."
git push origin main

echo "🧰 Flutter pub get..."
cd app
flutter pub get

echo "🚀 Flutter build web --release..."
flutter build web --release

echo "📦 Deploy to Firebase..."
cd ..
firebase deploy --only hosting,functions,firestore:rules,firestore:indexes

echo "✅ Déploiement terminé avec succès!"
