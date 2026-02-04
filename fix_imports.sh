#!/bin/bash
# Script de résolution des erreurs d'import

set -e

echo "🔧 RÉSOLUTION ERREURS D'IMPORT"
echo "=============================="
echo ""

cd /workspaces/MASLIVE

# Vérifier pubspec.yaml
echo "1️⃣ Vérifier pubspec.yaml..."
if grep -q "^name: masslive" app/pubspec.yaml; then
  echo "   ✅ Package name = masslive"
else
  echo "   ❌ Package name incorrect!"
  exit 1
fi

# Vérifier Hive dépendances
echo ""
echo "2️⃣ Vérifier Hive dépendances..."
if grep -q "hive_flutter" app/pubspec.yaml && grep -q "hive_generator" app/pubspec.yaml; then
  echo "   ✅ Hive dépendances présentes"
else
  echo "   ❌ Hive dépendances manquantes!"
  exit 1
fi

# Vérifier import dans test
echo ""
echo "3️⃣ Vérifier imports dans test..."
if grep -q "package:masslive/models/group_admin" app/test/services/group_tracking_test.dart; then
  echo "   ✅ Imports corrects dans test"
else
  echo "   ⚠️  Imports pas corrects!"
  echo "   Corrigeant..."
  sed -i 's/package:maslive_app/package:masslive/g' app/test/services/group_tracking_test.dart
  echo "   ✅ Imports corrigés"
fi

cd /workspaces/MASLIVE/app

# Flutter pub get
echo ""
echo "4️⃣ flutter pub get..."
flutter pub get || { echo "❌ Erreur flutter pub get"; exit 1; }
echo "   ✅ Dépendances installées"

# Flutter clean
echo ""
echo "5️⃣ flutter clean..."
flutter clean || true
echo "   ✅ Cache nettoyé"

# Build runner
echo ""
echo "6️⃣ Générer adapters Hive..."
flutter pub run build_runner build --delete-conflicting-outputs 2>&1 | grep -E "(Building|Succeeded|Failed)" || true
echo "   ✅ Adapters générés"

# Simple test
echo ""
echo "7️⃣ Test simple..."
flutter test test/simple_test.dart -v 2>&1 | tail -20

echo ""
echo "✅ RÉSOLUTION COMPLÉTÉE!"
echo ""
echo "Prochaines étapes:"
echo "  1. flutter test test/services/group_tracking_test.dart"
echo "  2. flutter build web --release"
echo "  3. firebase deploy --only hosting,functions"
