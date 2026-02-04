#!/bin/bash
# Vérification rapide des fichiers critiques

echo "🔍 VÉRIFICATION FICHIERS"
echo "======================="

cd /workspaces/MASLIVE

files=(
  "app/lib/utils/geo_utils.dart"
  "app/lib/models/group_admin.dart"
  "app/lib/services/group/group_average_service.dart"
  "app/lib/services/group/group_history_service.dart"
  "app/lib/services/group/group_cache_service.dart"
  "app/test/services/group_tracking_test.dart"
  "functions/group_tracking_improved.js"
  "pubspec.yaml"
)

echo ""
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    lines=$(wc -l < "$file")
    echo "✅ $file ($lines lignes)"
  else
    echo "❌ $file (MANQUANT)"
  fi
done

echo ""
echo "📦 Dépendances Hive:"
grep -E "hive|build_runner" app/pubspec.yaml || echo "❌ Hive not found in pubspec.yaml"

echo ""
echo "✅ Vérification complétée"
