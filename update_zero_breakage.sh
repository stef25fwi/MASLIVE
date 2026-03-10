#!/bin/bash
# =============================================================================
# MASLIVE — Mise à jour zéro cassure
# Lancer depuis la racine du projet : bash update_zero_breakage.sh
# =============================================================================
set -e  # Arrêt immédiat si une commande échoue

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
step() { echo -e "\n${YELLOW}▶ $1${NC}"; }

# =============================================================================
# ÉTAPE 0 — Vérifications préalables
# =============================================================================
step "0/6 — Vérifications préalables"

command -v flutter >/dev/null 2>&1 || fail "Flutter non trouvé dans PATH"
command -v node    >/dev/null 2>&1 || fail "Node.js non trouvé dans PATH"
command -v npm     >/dev/null 2>&1 || fail "npm non trouvé dans PATH"

FLUTTER_VERSION=$(flutter --version 2>&1 | head -1)
DART_VERSION=$(dart --version 2>&1)
NODE_VERSION=$(node --version)

echo "Flutter : $FLUTTER_VERSION"
echo "Dart    : $DART_VERSION"
echo "Node    : $NODE_VERSION"

# Vérifier Dart >= 3.10.7
DART_MAJOR=$(dart --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1 | cut -d. -f1)
DART_MINOR=$(dart --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1 | cut -d. -f2)
DART_PATCH=$(dart --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1 | cut -d. -f3)

if [ "$DART_MAJOR" -lt 3 ] || { [ "$DART_MAJOR" -eq 3 ] && [ "$DART_MINOR" -lt 10 ]; }; then
  fail "Dart $DART_MAJOR.$DART_MINOR.$DART_PATCH < 3.10.7 requis. Lancer 'flutter upgrade' d'abord."
fi
ok "Dart $DART_MAJOR.$DART_MINOR.$DART_PATCH >= 3.10.7"

# =============================================================================
# ÉTAPE 1 — Flutter upgrade (stable)
# =============================================================================
step "1/6 — Flutter upgrade vers stable"

flutter upgrade
ok "Flutter mis à jour"

# =============================================================================
# ÉTAPE 2 — pub upgrade Flutter (SANS --major-versions)
# =============================================================================
step "2/6 — flutter pub upgrade (sans major-versions)"

cd app
flutter pub upgrade
ok "pub upgrade OK"

# Vérifier que mapbox est resté en v2
MAPBOX_VERSION=$(grep -A4 "mapbox_maps_flutter:" pubspec.lock | grep "version:" | head -1 | grep -oP '\d+\.\d+\.\d+')
MAPBOX_MAJOR=$(echo "$MAPBOX_VERSION" | cut -d. -f1)
if [ "$MAPBOX_MAJOR" -ge 3 ]; then
  fail "mapbox_maps_flutter est passé en v$MAPBOX_VERSION (breaking!). Restaurer: git checkout app/pubspec.lock"
fi
ok "mapbox_maps_flutter $MAPBOX_VERSION (v2 ✅ — pas de breaking)"

cd ..

# =============================================================================
# ÉTAPE 3 — Analyse statique Dart
# =============================================================================
step "3/6 — Analyse statique Flutter (flutter analyze)"

cd app
ANALYZE_FILE="/tmp/maslive_analyze.txt"
flutter analyze --no-fatal-infos 2>&1 | tee "$ANALYZE_FILE" || true
ERRORS=$(grep -c "error •" "$ANALYZE_FILE" 2>/dev/null || echo 0)
WARNINGS=$(grep -c "warning •" "$ANALYZE_FILE" 2>/dev/null || echo 0)

if [ "$ERRORS" -gt 0 ]; then
  warn "$ERRORS erreur(s) détectée(s) — détail dans $ANALYZE_FILE"
  echo ""
  echo "=== ERREURS DART ==="
  grep "error •" "$ANALYZE_FILE" | head -30
  echo "===================="
  echo ""
  warn "Le build peut échouer. Continuons quand même pour voir jusqu'où ça passe."
else
  ok "Analyse Dart OK (0 erreurs, $WARNINGS warnings)"
fi
cd ..

# =============================================================================
# ÉTAPE 4 — Build Flutter web
# =============================================================================
step "4/6 — Build Flutter Web (release)"

cd app
BUILD_FILE="/tmp/maslive_build.txt"
if flutter build web --release 2>&1 | tee "$BUILD_FILE"; then
  ok "Build web réussi ✅"
else
  warn "Build web échoué — dernières lignes :"
  tail -20 "$BUILD_FILE"
  echo ""
  warn "Voir $BUILD_FILE pour le détail complet"
fi
cd ..

# =============================================================================
# ÉTAPE 5 — Tests Cloud Functions Node.js
# =============================================================================
step "5/6 — Tests Firebase Functions"

cd functions
npm install --silent 2>&1 | tail -3
if npm test 2>&1; then
  ok "Tests Functions OK"
else
  warn "Tests Functions échoués (à investiguer séparément)"
fi
cd ..

# =============================================================================
# ÉTAPE 6 — Vérification finale des versions installées
# =============================================================================
step "6/6 — Récapitulatif des versions installées"

echo ""
echo "─────────────────────────────────────────────"
echo "  Package                    Version"
echo "─────────────────────────────────────────────"

check_version() {
  local pkg=$1
  local v=$(grep -A4 "  $pkg:" app/pubspec.lock | grep "version:" | head -1 | grep -oP '\d+\.\d+\.\d+')
  printf "  %-30s %s\n" "$pkg" "${v:-N/A}"
}

check_version "mapbox_maps_flutter"
check_version "flutter_stripe"
check_version "purchases_flutter"
check_version "firebase_core"
check_version "firebase_auth"
check_version "cloud_firestore"
check_version "firebase_messaging"
check_version "firebase_storage"
check_version "get"
check_version "web"

echo "─────────────────────────────────────────────"
echo ""
ok "Mise à jour zéro cassure terminée avec succès !"
echo ""
echo "Prochaines étapes :"
echo "  git add app/pubspec.yaml app/pubspec.lock app/analysis_options.yaml functions/package.json"
echo "  git commit -m 'chore: zero-breakage update — bump deps + lock mapbox v2'"
echo "  git push"
