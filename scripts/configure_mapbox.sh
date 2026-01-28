#!/bin/bash

# Script de configuration du token Mapbox pour MASLIVE
# Usage: bash scripts/configure_mapbox.sh [token]

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo "🗺️  Configuration Token Mapbox - MASLIVE"
echo "========================================"
echo ""

# Si token passé en argument
if [ -n "$1" ]; then
    MAPBOX_TOKEN="$1"
else
    # Sinon demander à l'utilisateur
    echo "📝 Entre ton token public Mapbox (commence par 'pk.'):"
    echo "   Obtiens-le sur: https://account.mapbox.com/access-tokens/"
    echo ""
    read -r MAPBOX_TOKEN
fi

# Valider le format du token
if [[ ! "$MAPBOX_TOKEN" =~ ^pk\. ]]; then
    echo "❌ Erreur: Le token doit commencer par 'pk.'"
    echo "   Exemple: pk.eyJ1IjoibWFzbGl2ZSIsImEiOiJja..."
    exit 1
fi

# Créer/mettre à jour le fichier .env
echo "💾 Enregistrement du token dans $ENV_FILE..."
if [ -f "$ENV_FILE" ]; then
    # Supprimer les anciennes lignes MAPBOX_PUBLIC_TOKEN et MAPBOX_ACCESS_TOKEN
    sed -i '/^MAPBOX_PUBLIC_TOKEN=/d' "$ENV_FILE"
    sed -i '/^MAPBOX_ACCESS_TOKEN=/d' "$ENV_FILE"
    sed -i '/^MAPBOX_TOKEN=/d' "$ENV_FILE"
fi

# Ajouter le nouveau token (format recommandé)
{
    echo ""
    echo "# Mapbox Configuration (configuré le $(date '+%Y-%m-%d %H:%M'))"
    echo "MAPBOX_ACCESS_TOKEN=$MAPBOX_TOKEN"
    echo "MAPBOX_PUBLIC_TOKEN=$MAPBOX_TOKEN"
} >> "$ENV_FILE"

echo "✅ Token Mapbox configuré!"
echo ""
echo "📌 Configuration enregistrée dans: $ENV_FILE"
echo ""
echo "🚀 Options de déploiement:"
echo ""
echo "1️⃣  Build Web avec token (intégré au build):"
echo "   export MAPBOX_ACCESS_TOKEN='$MAPBOX_TOKEN'"
echo "   cd app && flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN=\"\$MAPBOX_ACCESS_TOKEN\""
echo ""
echo "2️⃣  Déployer avec le script existant:"
echo "   bash scripts/deploy_with_mapbox.sh '$MAPBOX_TOKEN'"
echo ""
echo "3️⃣  Utiliser les tâches VS Code (auto-détection):"
echo "   export MAPBOX_ACCESS_TOKEN='$MAPBOX_TOKEN'"
echo "   Puis: Tâche > MASLIVE: Déployer Hosting (1 clic)"
echo ""
echo "4️⃣  Configuration Runtime (déjà dans le build):"
echo "   Si tu build sans --dart-define, l'app propose un bouton"
echo "   'Configurer' pour saisir le token dans l'UI (SharedPreferences)."
echo ""
echo "✨ Token visible (15 premiers caractères): ${MAPBOX_TOKEN:0:15}..."
echo ""

# Ajouter .env au .gitignore si pas déjà présent
if ! grep -q "^\.env$" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
    echo "🔒 Ajout de .env au .gitignore pour la sécurité..."
    echo "" >> "$PROJECT_ROOT/.gitignore"
    echo "# Environment variables (tokens, secrets)" >> "$PROJECT_ROOT/.gitignore"
    echo ".env" >> "$PROJECT_ROOT/.gitignore"
    echo "✅ .gitignore mis à jour"
fi

echo ""
echo "🎉 Configuration terminée!"
