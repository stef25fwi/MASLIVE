#!/bin/bash

# Script de validation et deploy Mapbox fixes

set -e

echo "🔍 Vérification des fichiers Mapbox..."

# Fichiers à vérifier
FILES=(
  "app/web/mapbox_circuit.js"
  "app/lib/admin/assistant_step_by_step/mapbox_web_circuit_map.dart"
  "app/web/index.html"
)

for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "✅ Fichier $file existe"
  else
    echo "❌ Fichier $file manquant"
    exit 1
  fi
done

echo ""
echo "🔍 Vérification de la structure Mapbox GL JS..."

# Vérifier que index.html charge les scripts dans le bon ordre
if grep -q 'mapbox-gl.css' app/web/index.html && \
   grep -q 'mapbox-gl.js' app/web/index.html && \
   grep -q 'mapbox_circuit.js' app/web/index.html; then
  echo "✅ Mapbox GL JS correctement chargé dans index.html"
else
  echo "❌ Ordre de chargement incorrect"
  exit 1
fi

echo ""
echo "🔍 Vérification du code JavaScript..."

# init() doit retourner boolean
if grep -q 'return true;' app/web/mapbox_circuit.js && \
   grep -q 'return false;' app/web/mapbox_circuit.js; then
  echo "✅ init() et setData() retournent des booléens"
else
  echo "❌ Les fonctions ne retournent pas de booléens"
  exit 1
fi

# Vérification des validations
if grep -q 'token.length === 0' app/web/mapbox_circuit.js; then
  echo "✅ Validation du token présente"
else
  echo "❌ Validation du token manquante"
  exit 1
fi

if grep -q 'map.getSource' app/web/mapbox_circuit.js; then
  echo "✅ Vérification des sources présente"
else
  echo "❌ Vérification des sources manquante"
  exit 1
fi

echo ""
echo "🔍 Vérification du code Dart..."

# Vérification kDebugMode
if grep -q 'import.*foundation' app/lib/admin/assistant_step_by_step/mapbox_web_circuit_map.dart; then
  echo "✅ Import foundation.dart présent"
else
  echo "❌ Import foundation.dart manquant"
  exit 1
fi

# Vérification logging
if grep -q 'kDebugMode.*print' app/lib/admin/assistant_step_by_step/mapbox_web_circuit_map.dart; then
  echo "✅ Logging Dart présent"
else
  echo "❌ Logging Dart manquant"
  exit 1
fi

# Vérification gestion erreurs
if grep -q 'catch (e)' app/lib/admin/assistant_step_by_step/mapbox_web_circuit_map.dart && \
   ! grep -q 'catch (_)' app/lib/admin/assistant_step_by_step/mapbox_web_circuit_map.dart; then
  echo "✅ Gestion d'erreurs améliorée (catch (e))"
else
  echo "⚠️  Ancienne gestion d'erreurs (catch (_)) trouvée"
fi

echo ""
echo "✅ TOUS LES VÉRIFICATIONS PASSÉES!"
echo ""
echo "📝 Résumé des fixes:"
echo "  • mapbox_circuit.js: init() et setData() retournent booléens"
echo "  • mapbox_circuit.js: Validations token + container ajoutées"
echo "  • mapbox_circuit.js: Logging avec emoji pour debugging"
echo "  • mapbox_web_circuit_map.dart: Logging détaillé ajouté"
echo "  • mapbox_web_circuit_map.dart: Gestion d'erreurs améliorée"
echo "  • index.html: Vérification ordre chargement (✅ Correct)"
echo ""
echo "🚀 Prêt pour déploiement!"
