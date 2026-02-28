#!/bin/bash

# Interactive Mapbox Configuration Setup
# Configures MAPBOX_ACCESS_TOKEN for MASLIVE project

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🎯 Configuration Mapbox Access Token"
echo "===================================="
echo ""
echo "Ce script configure le token Mapbox pour le projet MASLIVE"
echo ""

# Check if .env exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "⚠️  Fichier .env existant trouvé"
    read -p "Voulez-vous le remplacer? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Configuration annulée"
        exit 1
    fi
fi

# Get token from user
echo ""
echo "📌 Comment obtenir votre token Mapbox:"
echo "   1. Rendez-vous sur https://account.mapbox.com/tokens/"
echo "   2. Créez un nouveau token (Create a token)"
echo "   3. Copiez le token public (pk....)"
echo ""

read -p "Entrez votre Mapbox Public Token (pk....): " MAPBOX_TOKEN

# Validate token
if [ -z "$MAPBOX_TOKEN" ]; then
    echo "❌ Erreur: Token vide"
    exit 1
fi

if [[ ! $MAPBOX_TOKEN =~ ^pk[\._] ]]; then
    echo "❌ Erreur: Le token doit commencer par 'pk.' (ou 'pk_')"
    exit 1
fi

# Create .env file
echo "💾 Création du fichier .env..."
cat > "$PROJECT_ROOT/.env" << EOF
# Mapbox Configuration
# Token: ${MAPBOX_TOKEN:0:15}...
MAPBOX_ACCESS_TOKEN=$MAPBOX_TOKEN
MAPBOX_PUBLIC_TOKEN=$MAPBOX_TOKEN
MAPBOX_TOKEN=$MAPBOX_TOKEN

# Generated: $(date)
EOF

echo "✅ Fichier .env créé"
echo ""

# Add to .gitignore
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    if ! grep -q "^\.env" "$PROJECT_ROOT/.gitignore"; then
        echo ".env" >> "$PROJECT_ROOT/.gitignore"
        echo "✅ .env ajouté à .gitignore"
    fi
else
    echo ".env" > "$PROJECT_ROOT/.gitignore"
    echo "✅ .gitignore créé avec .env"
fi

echo ""
echo "🧪 Test de configuration..."
echo ""

# Test by trying to build
read -p "Voulez-vous tester le build maintenant? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔨 Démarrage du build..."
    source "$PROJECT_ROOT/.env"
    bash "$PROJECT_ROOT/scripts/build_with_mapbox.sh" "$MAPBOX_PUBLIC_TOKEN"
else
    echo "⏭️  Build skippé"
    echo ""
    echo "Pour builder manuellement:"
    echo "  bash $PROJECT_ROOT/scripts/build_with_mapbox.sh"
fi

echo ""
echo "✨ Configuration Mapbox terminée!"
echo ""
echo "📋 Résumé:"
echo "   ✅ Fichier .env configuré"
echo "   ✅ Token Mapbox: ${MAPBOX_TOKEN:0:15}..."
echo "   ✅ .gitignore mis à jour"
echo ""
echo "🚀 Prochaines étapes:"
echo "   1. Tester localement: flutter run -d chrome"
echo "   2. Vérifier les cartes Mapbox chargent correctement"
echo "   3. Builder et déployer: bash scripts/build_with_mapbox.sh"
echo ""
