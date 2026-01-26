#!/bin/bash

# One-click Mapbox build and deploy script
# Usage: bash scripts/deploy_with_mapbox.sh [token]

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 MASLIVE - Deploy avec Mapbox Token"
echo "===================================="
echo ""

# Get token
MAPBOX_TOKEN="${1}"

# Try .env if no argument
if [ -z "$MAPBOX_TOKEN" ] && [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    MAPBOX_TOKEN="$MAPBOX_PUBLIC_TOKEN"
fi

# Try environment variable
if [ -z "$MAPBOX_TOKEN" ]; then
    MAPBOX_TOKEN="$MAPBOX_PUBLIC_TOKEN"
fi

if [ -z "$MAPBOX_TOKEN" ]; then
    echo "❌ Erreur: MAPBOX_PUBLIC_TOKEN non trouvé"
    echo ""
    echo "Usage:"
    echo "  bash scripts/deploy_with_mapbox.sh 'pk_your_token'"
    echo ""
    echo "Ou créer .env:"
    echo "  bash scripts/setup_mapbox.sh"
    exit 1
fi

echo "✅ Token détecté: ${MAPBOX_TOKEN:0:15}..."
echo ""

# Step 1: Build
echo "🔨 Build Web avec Mapbox..."
cd "$PROJECT_ROOT/app"
flutter pub get
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN"
echo "✅ Build terminé"
echo ""

# Step 2: Deploy
echo "📤 Déploiement Firebase Hosting..."
cd "$PROJECT_ROOT"
firebase deploy --only hosting
echo "✅ Déploiement terminé"
echo ""

echo "🌍 Application disponible sur: https://maslive.web.app"
echo "✨ Mapbox intégré et fonctionnel!"
