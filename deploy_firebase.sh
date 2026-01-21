#!/bin/bash
# Déploiement Firebase uniquement

set -e

echo "🌍 DÉPLOIEMENT FIREBASE"
echo "======================="
echo ""

# Build web
echo "[1/3] 🏗️  Build Flutter web..."
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release
cd /workspaces/MASLIVE
echo "✅ Build complété"
echo ""

# Deploy Firestore rules
echo "[2/3] 📋 Deploy Firestore rules..."
firebase deploy --only firestore:rules
echo "✅ Firestore rules déployées"
echo ""

# Deploy hosting + functions
echo "[3/3] 🚀 Deploy hosting et functions..."
firebase deploy --only hosting,functions
echo "✅ Hosting et functions déployés"
echo ""

echo "════════════════════════════"
echo "✅ FIREBASE DÉPLOYÉ!"
echo "════════════════════════════"
