#!/bin/bash
# Script pour setup et tester les améliorations

set -e

echo "🔧 SETUP DES AMÉLIORATIONS"
echo "=========================="

cd /workspaces/MASLIVE/app

echo ""
echo "1️⃣ Installer les dépendances..."
flutter pub get

echo ""
echo "2️⃣ Générer les adapters Hive..."
flutter pub run build_runner build --delete-conflicting-outputs 2>&1 | tail -20

echo ""
echo "3️⃣ Lancer les tests unitaires..."
flutter test test/services/group_tracking_test.dart -v 2>&1 | tail -100

echo ""
echo "✅ SETUP COMPLÉTÉ!"
echo ""
echo "Prochaines étapes:"
echo "  1. firebase deploy --only functions:calculateGroupAveragePosition"
echo "  2. Tester dans l'app (admin, tracker, GPS)"
echo "  3. Vérifier logs: firebase functions:log"
