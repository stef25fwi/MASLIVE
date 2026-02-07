#!/bin/bash
set -e

cd /workspaces/MASLIVE

echo "📝 Git add..."
git add app/lib/pages/home_map_page_web.dart

echo "📝 Git commit..."
git commit -m "fix: syntax error in home_map_page_web.dart (Future.delayed callback)"

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
