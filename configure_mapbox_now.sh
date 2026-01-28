#!/bin/bash

# 🗺️ CONFIGURATION RAPIDE MAPBOX TOKEN
# =====================================
# Ce script configure le token Mapbox en 30 secondes

clear
echo "╔════════════════════════════════════════════════╗"
echo "║   🗺️  Configuration Token Mapbox - MASLIVE   ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Vérifier si un token existe déjà
if [ -n "$MAPBOX_ACCESS_TOKEN" ]; then
    echo -e "${GREEN}✓${NC} Token déjà configuré dans l'environnement"
    echo "  Token: ${MAPBOX_ACCESS_TOKEN:0:15}..."
    echo ""
    read -p "Veux-tu le remplacer ? (o/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
        echo "Configuration annulée."
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}📍 Où obtenir ton token ?${NC}"
echo "   → https://account.mapbox.com/access-tokens/"
echo ""
echo -e "${YELLOW}⚠️  Tu as besoin d'un token PUBLIC (commence par 'pk.')${NC}"
echo ""

# Demander le token
read -p "🔑 Colle ton token Mapbox ici: " MAPBOX_TOKEN

# Validation
if [ -z "$MAPBOX_TOKEN" ]; then
    echo -e "${RED}✗ Aucun token fourni${NC}"
    exit 1
fi

if [[ ! "$MAPBOX_TOKEN" =~ ^pk\. ]]; then
    echo -e "${RED}✗ Erreur: Le token doit commencer par 'pk.'${NC}"
    echo "  Format attendu: pk.eyJ1IjoibWFzbGl2ZSIsImEiOiJja..."
    exit 1
fi

# Créer/mettre à jour .env
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo ""
echo -e "${BLUE}💾 Enregistrement...${NC}"

# Backup si existe
if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    # Nettoyer anciennes entrées
    sed -i.tmp '/^MAPBOX_/d' "$ENV_FILE" && rm -f "$ENV_FILE.tmp"
fi

# Écrire la nouvelle config
{
    echo ""
    echo "# Mapbox Configuration ($(date '+%Y-%m-%d %H:%M'))"
    echo "MAPBOX_ACCESS_TOKEN=$MAPBOX_TOKEN"
    echo "MAPBOX_PUBLIC_TOKEN=$MAPBOX_TOKEN"
    echo "MAPBOX_TOKEN=$MAPBOX_TOKEN"
} >> "$ENV_FILE"

# Ajouter .env au .gitignore si absent
if ! grep -q "^\.env$" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
    echo "" >> "$PROJECT_ROOT/.gitignore"
    echo "# Environment variables" >> "$PROJECT_ROOT/.gitignore"
    echo ".env" >> "$PROJECT_ROOT/.gitignore"
fi

# Exporter pour la session courante
export MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN"
export MAPBOX_PUBLIC_TOKEN="$MAPBOX_TOKEN"
export MAPBOX_TOKEN="$MAPBOX_TOKEN"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ Configuration OK !             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓${NC} Token enregistré dans: $ENV_FILE"
echo -e "${GREEN}✓${NC} Variables exportées pour ce terminal"
echo -e "${GREEN}✓${NC} .gitignore mis à jour (sécurité)"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}🚀 PROCHAINES ÉTAPES:${NC}"
echo ""
echo "1️⃣  Déployer avec Mapbox (méthode express):"
echo "   ${GREEN}bash scripts/deploy_with_mapbox.sh${NC}"
echo ""
echo "2️⃣  Ou build manuellement:"
echo "   ${GREEN}cd app && flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN=\"\$MAPBOX_ACCESS_TOKEN\"${NC}"
echo ""
echo "3️⃣  Ou via tâche VS Code:"
echo "   ${GREEN}Terminal > Exécuter la tâche > MASLIVE: Déployer Hosting (1 clic)${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}💡 Astuce:${NC} Si tu as déjà déployé sans token, tu peux aussi"
echo "   configurer le token directement dans l'UI:"
echo "   Home → Bandeau 'Mapbox inactif' → Bouton ${GREEN}Configurer${NC}"
echo ""
echo "Token aperçu: ${MAPBOX_TOKEN:0:20}..."
echo ""
