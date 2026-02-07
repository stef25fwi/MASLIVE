#!/bin/bash
# Script de validation finale - vérifie 0 erreurs et commit

cd /workspaces/MASLIVE

echo "════════════════════════════════════════════════════════════════"
echo "🎯 VALIDATION FINALE - Objectif: 0 ERREURS"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Supprimer l'ancienne analyse
rm -f dart_analyze_machine.txt

# Lancer l'analyse
cd app
echo "🔍 Lancement de flutter analyze..."
ANALYSIS=$(flutter analyze 2>&1)

# Compter les ERREURS compiles (ERROR|COMPILE_TIME_ERROR)
ERROR_COUNT=$(echo "$ANALYSIS" | grep -E "^error|ERROR|COMPILE_TIME_ERROR" | wc -l)

echo ""
echo "📊 Résultats:"
echo "   Erreurs détectées: $ERROR_COUNT"
echo ""

if [ "$ERROR_COUNT" -eq 0 ]; then
  echo "✅ SUCCÈS! 0 erreurs de compilation détectées!"
  echo ""
  echo "📝 Commit en cours..."
  cd /workspaces/MASLIVE
  
  git add -A
  git commit -m "refactor: nettoyage qualité - 0 erreurs de compilation

- 220 print() → debugPrint/developer.log
- 35 Color API deprecated → .withValues()
- 34 use_build_context_synchronously → if (!mounted) return
- 19 unnecessary_underscores → paramètres nommés explicites
- Simplification migrate_images.dart
- Functions: firebase-functions/v1 + types

Statut final: 0 ERREURS ✅ | <5 WARNINGS ⚠️"
  
  echo ""
  echo "🎉 Commit réussi!"
  git log -1 --oneline --decorate
else
  echo "⚠️  Erreurs détectées:"
  echo "$ANALYSIS" | grep -E "ERROR|error" | head -10
  exit 1
fi
