#!/bin/bash
cd /workspaces/MASLIVE/app

echo "═══════════════════════════════════════════════════════════════"
echo "🔍 Flutter Analyzer - Vérification des erreurs (0 tolérance)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Compter les ERREURS (severity = ERROR uniquement)
echo "📊 Statistiques:"
echo ""

ERROR_COUNT=$(flutter analyze 2>&1 | grep -c "^error" || true)
WARNING_COUNT=$(flutter analyze 2>&1 | grep -c "^warning" || true)
INFO_COUNT=$(flutter analyze 2>&1 | grep -c "^info" || true)

echo "  ❌ ERREURS:     $ERROR_COUNT"
echo "  ⚠️  WARNINGS:    $WARNING_COUNT"
echo "  ℹ️  INFOS:       $INFO_COUNT"
echo ""

if [ "$ERROR_COUNT" -eq 0 ]; then
  echo "✅ SUCCÈS: 0 erreurs détectées!"
  echo ""
  echo "🎉 Statut: READY FOR COMMIT"
  exit 0
else
  echo "❌ ERREURS À CORRIGER:"
  echo ""
  flutter analyze 2>&1 | grep "^error" | head -20
  exit 1
fi
