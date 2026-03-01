#!/bin/bash

# Build Flutter Web with Mapbox Token
# Usage: bash scripts/build_with_mapbox.sh [token]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 MASLIVE - Build Web avec Mapbox"
echo "=================================="
echo ""

# Get token from argument or environment
TOKEN_ARG="${1:-}"
TOKEN_ENV="${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}}"
MAPBOX_TOKEN="${TOKEN_ARG:-$TOKEN_ENV}"

# Try to load from .env
if [ -z "$MAPBOX_TOKEN" ] && [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    TOKEN_ENV="${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}}"
    MAPBOX_TOKEN="$TOKEN_ENV"
fi

# Verify token
if [ -z "$MAPBOX_TOKEN" ]; then
    echo "❌ Erreur: token Mapbox non fourni (MAPBOX_ACCESS_TOKEN / MAPBOX_PUBLIC_TOKEN / MAPBOX_TOKEN)"
    echo ""
    echo "Usage:"
    echo "  1. Passer le token en argument:"
    echo "     bash scripts/build_with_mapbox.sh 'pk.your_token_here'"
    echo ""
    echo "  2. Ou définir via environnement:"
    echo "     export MAPBOX_ACCESS_TOKEN='pk.your_token_here'"
    echo "     # ou: export MAPBOX_PUBLIC_TOKEN='pk.your_token_here'"
    echo "     bash scripts/build_with_mapbox.sh"
    echo ""
    echo "  3. Ou créer .env à la racine:"
    echo "     echo 'MAPBOX_ACCESS_TOKEN=pk.your_token_here' > .env"
    echo "     echo 'MAPBOX_PUBLIC_TOKEN=pk.your_token_here' >> .env"
    echo "     bash scripts/build_with_mapbox.sh"
    exit 1
fi

# Validate token format
if [[ ! $MAPBOX_TOKEN =~ ^pk[\._] ]]; then
    echo "⚠️  Attention: le token ne commence pas par 'pk.' (ou 'pk_')"
    echo "   Assurez-vous qu'il s'agit d'un token PUBLIC Mapbox"
    echo ""
    read -p "Continuer? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ Token Mapbox détecté: OK (redacted)"
echo ""

# Step 1: Clean previous builds
echo "🧹 Nettoyage builds précédents..."
cd "$PROJECT_ROOT/app"
rm -rf build/web
echo "✅ Nettoyage terminé"
echo ""

# Step 2: Get dependencies
echo "📦 Récupération des dépendances..."
flutter pub get
echo "✅ Dépendances à jour"
echo ""

# Step 3: Build web
echo "🔨 Build Web avec Mapbox..."
flutter build web --release \
    --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN"
echo "✅ Build Web terminé"
echo ""

# Step 4: Check build output
echo "📊 Vérification du build..."
BUILD_SIZE=$(du -sh build/web | cut -f1)
FILE_COUNT=$(find build/web -type f | wc -l)
echo "   Taille: $BUILD_SIZE"
echo "   Fichiers: $FILE_COUNT"
echo ""

# Step 5: Optional deploy
echo "🚀 Déployer vers Firebase Hosting?"
echo "   (La carte Mapbox sera accessible sur https://maslive.web.app)"
read -p "Déployer? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$PROJECT_ROOT"
    echo "📤 Déploiement en cours..."
    firebase deploy --only hosting
    echo ""
    echo "✅ Déploiement terminé!"
    echo "🌍 URL: https://maslive.web.app"
else
    echo "⏭️  Déploiement skippé"
    echo "   Build disponible dans: $PROJECT_ROOT/app/build/web"
fi

echo ""
echo "✨ Processus terminé!"
