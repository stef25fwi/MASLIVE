#!/bin/bash

# Script de déploiement complet MASLIVE
# Effectue : commit → push → build Flutter → déploiement Firebase

set -e  # Exit on error

echo "🚀 Déploiement MASLIVE - $(date '+%Y%m%d_%H%M%S')"
echo "=================================================="

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Étape 1: Vérifier le statut git
echo -e "${BLUE}📋 Étape 1: Vérifier les changements...${NC}"
git status

# Étape 2: Ajouter tous les fichiers
echo -e "${BLUE}📝 Étape 2: Ajouter tous les fichiers...${NC}"
git add -A

# Étape 3: Créer le commit
echo -e "${BLUE}💾 Étape 3: Créer le commit...${NC}"
git commit -m "feat: animation menu navigation + dashboard admin réorganisé + section comptes pro

- Ajouter animation de glissement (slide transition) pour fermer la barre de navigation verticale avant navigation vers Compte/Shop
- Réorganiser le dashboard administrateur avec 6 sections claires :
  * Carte & Navigation (circuits, POIs)
  * Tracking & Groupes (suivi live, groupes)
  * Commerce (produits, commandes, Stripe)
  * Utilisateurs (gestion rôles)
  * Comptes Professionnels (demandes pro - NEW)
  * Analytics & Système (stats, logs, config)
- Ajouter tuile 'Demandes Pro' dans section Comptes Professionnels
- Ajouter documentation ADMIN_DASHBOARD_STRUCTURE.md
- Ajouter guide configuration webhook Stripe (STRIPE_WEBHOOK_SETUP.md)
- Ajouter rapport statut déploiement (DEPLOYMENT_STATUS_20260124.md)"

# Étape 4: Push vers origin
echo -e "${BLUE}⬆️  Étape 4: Pusher vers origin/main...${NC}"
git push origin main

# Étape 5: Builder l'app Flutter
echo -e "${BLUE}🔨 Étape 5: Builder l'app Flutter (web)...${NC}"
cd app
flutter clean
flutter pub get
flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://www.gstatic.com/flutter-canvaskit/

# Étape 6: Retour au répertoire racine
cd ..

# Étape 7: Déployer sur Firebase
echo -e "${BLUE}🌐 Étape 6: Déployer sur Firebase (hosting + functions + rules + indexes)...${NC}"
firebase deploy --only hosting,functions,firestore:rules,firestore:indexes

echo -e "${GREEN}✅ Déploiement réussi !${NC}"
echo "=================================================="
echo -e "${GREEN}📊 Résumé :${NC}"
echo "  ✓ Commit créé et pushé"
echo "  ✓ App Flutter buildée (web)"
echo "  ✓ Hosting Firebase déployé"
echo "  ✓ Cloud Functions déployées"
echo "  ✓ Firestore rules et indexes mis à jour"
echo ""
echo -e "${YELLOW}📌 Pour vérifier le déploiement:${NC}"
echo "  - Dashboard Firebase: https://console.firebase.google.com/project/maslive"
echo "  - App live: https://maslive.web.app"
echo "  - Logs functions: firebase functions:log"
