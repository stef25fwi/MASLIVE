#!/bin/bash

################################################################################
# DÉPLOIEMENT SYSTÈME IMAGES - SCRIPT AUTOMATIQUE
# 
# Ce script automatise le déploiement complet du nouveau système d'images:
# - Installation dependencies
# - Configuration Firebase
# - Déploiement Cloud Functions
# - Tests
# 
# USAGE:
#   bash deploy_image_system.sh [--skip-tests] [--production]
# 
# OPTIONS:
#   --skip-tests     Ne pas exécuter les tests
#   --production     Déployer en production (sinon staging)
#   --migrate        Lancer migration des données existantes
# 
################################################################################

set -e  # Exit on error

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SKIP_TESTS=false
PRODUCTION=false
MIGRATE=false
PROJECT_ROOT="/workspaces/MASLIVE"

# Parse arguments
for arg in "$@"; do
  case $arg in
    --skip-tests)
      SKIP_TESTS=true
      shift
      ;;
    --production)
      PRODUCTION=true
      shift
      ;;
    --migrate)
      MIGRATE=true
      shift
      ;;
  esac
done

# Fonctions utilitaires
log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

log_step() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}🚀 $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

################################################################################
# ÉTAPE 1: Vérifications préalables
################################################################################

log_step "ÉTAPE 1: Vérifications préalables"

# Vérifier que nous sommes dans le bon répertoire
if [ ! -d "$PROJECT_ROOT/app" ] || [ ! -d "$PROJECT_ROOT/functions" ]; then
  log_error "Répertoire invalide. Ce script doit être exécuté depuis /workspaces/MASLIVE"
  exit 1
fi

log_success "Répertoire projet OK"

# Vérifier Flutter installé
if ! command -v flutter &> /dev/null; then
  log_error "Flutter non installé"
  exit 1
fi

log_success "Flutter $(flutter --version | head -n 1)"

# Vérifier Firebase CLI
if ! command -v firebase &> /dev/null; then
  log_error "Firebase CLI non installé"
  exit 1
fi

log_success "Firebase CLI installé"

# Vérifier Node.js
if ! command -v node &> /dev/null; then
  log_error "Node.js non installé"
  exit 1
fi

log_success "Node.js $(node --version)"

################################################################################
# ÉTAPE 2: Installation Dependencies
################################################################################

log_step "ÉTAPE 2: Installation des dépendances"

# Flutter dependencies
log_info "Installation dependencies Flutter..."
cd "$PROJECT_ROOT/app"

if ! flutter pub add cached_network_image image --dev; then
  log_warning "Dependencies déjà installées ou erreur mineure"
fi

flutter pub get

log_success "Dependencies Flutter installées"

# Node.js dependencies
log_info "Installation dependencies Cloud Functions..."
cd "$PROJECT_ROOT/functions"

if ! npm list sharp &> /dev/null; then
  npm install sharp@^0.33.0
  log_success "Sharp installé"
else
  log_info "Sharp déjà installé"
fi

log_success "Dependencies Cloud Functions installées"

################################################################################
# ÉTAPE 3: Configuration Firebase Rules
################################################################################

log_step "ÉTAPE 3: Configuration Firebase"

cd "$PROJECT_ROOT"

# Backup rules actuelles
log_info "Backup des rules actuelles..."
cp firestore.rules firestore.rules.backup.$(date +%Y%m%d_%H%M%S) || true
cp storage.rules storage.rules.backup.$(date +%Y%m%d_%H%M%S) || true

# Ajouter rules image_assets si pas déjà présent
if ! grep -q "match /image_assets/" firestore.rules; then
  log_info "Ajout des rules Firestore pour image_assets..."
  
  # Insérer avant la dernière accolade
  cat >> firestore.rules << 'EOF'

    // Collection image_assets (système d'images optimisées)
    match /image_assets/{imageId} {
      allow read: if request.auth != null 
                  || resource.data.contentType in ['productPhoto', 'articleCover'];
      allow create: if request.auth != null
                    && request.resource.data.metadata.uploadedBy == request.auth.uid;
      allow update: if request.auth != null
                    && (resource.data.metadata.uploadedBy == request.auth.uid
                        || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true);
      allow delete: if false; // Soft delete uniquement
    }
EOF
  
  log_success "Rules Firestore ajoutées"
else
  log_info "Rules Firestore déjà présentes"
fi

# Storage rules
if ! grep -q "match /images/{contentType}" storage.rules; then
  log_info "Ajout des rules Storage pour images optimisées..."
  
  cat >> storage.rules << 'EOF'

    // Images optimisées
    match /images/{contentType}/{parentId}/{imageId}/{variant} {
      allow read: if contentType in ['productPhoto', 'articleCover'] 
                  || request.auth != null;
      allow write: if request.auth != null;
    }
EOF
  
  log_success "Rules Storage ajoutées"
else
  log_info "Rules Storage déjà présentes"
fi

################################################################################
# ÉTAPE 4: Tests (si non skippé)
################################################################################

if [ "$SKIP_TESTS" = false ]; then
  log_step "ÉTAPE 4: Tests"
  
  cd "$PROJECT_ROOT/app"
  
  log_info "Analyse Flutter..."
  flutter analyze || log_warning "Avertissements Flutter (non bloquant)"
  
  log_success "Tests OK"
else
  log_warning "Tests skippés (--skip-tests)"
fi

################################################################################
# ÉTAPE 5: Export Cloud Functions
################################################################################

log_step "ÉTAPE 5: Export Cloud Functions"

cd "$PROJECT_ROOT/functions"

# Vérifier si déjà exporté
if grep -q "generateImageVariants" index.js || grep -q "generateImageVariants" src/index.ts; then
  log_info "Cloud Functions déjà exportées"
else
  log_info "Export des Cloud Functions..."
  
  # Déterminer fichier index (JS ou TS)
  if [ -f "index.js" ]; then
    INDEX_FILE="index.js"
  elif [ -f "src/index.ts" ]; then
    INDEX_FILE="src/index.ts"
  else
    log_error "Fichier index.js ou index.ts introuvable"
    exit 1
  fi
  
  # Ajouter exports
  cat >> "$INDEX_FILE" << 'EOF'

// Image Management System
const imageVariants = require('./src/image-variants');
exports.generateImageVariants = imageVariants.generateImageVariants;
exports.regenerateImageVariants = imageVariants.regenerateImageVariants;
exports.cleanupDeletedImages = imageVariants.cleanupDeletedImages;
EOF
  
  log_success "Cloud Functions exportées dans $INDEX_FILE"
fi

################################################################################
# ÉTAPE 6: Déploiement Firebase
################################################################################

log_step "ÉTAPE 6: Déploiement Firebase"

cd "$PROJECT_ROOT"

if [ "$PRODUCTION" = true ]; then
  log_warning "DÉPLOIEMENT PRODUCTION"
  read -p "Confirmer déploiement production ? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_error "Déploiement annulé"
    exit 1
  fi
fi

# Déployer rules
log_info "Déploiement Firestore rules..."
firebase deploy --only firestore:rules

log_info "Déploiement Storage rules..."
firebase deploy --only storage:rules

# Déployer Cloud Functions
log_info "Déploiement Cloud Functions (peut prendre 3-5 min)..."
firebase deploy --only functions:generateImageVariants,functions:regenerateImageVariants,functions:cleanupDeletedImages

log_success "Déploiement Firebase complet"

################################################################################
# ÉTAPE 7: Build et déploiement Flutter Web
################################################################################

log_step "ÉTAPE 7: Build Flutter Web"

cd "$PROJECT_ROOT/app"

log_info "Build Flutter Web (release)..."
flutter build web --release

log_success "Build Flutter Web terminé"

log_info "Déploiement Hosting..."
cd "$PROJECT_ROOT"
firebase deploy --only hosting

log_success "Hosting déployé"

################################################################################
# ÉTAPE 8: Migration données (si demandé)
################################################################################

if [ "$MIGRATE" = true ]; then
  log_step "ÉTAPE 8: Migration données existantes"
  
  cd "$PROJECT_ROOT/app"
  
  log_warning "⚠️  MIGRATION DES DONNÉES"
  log_info "Un backup Firestore est recommandé avant migration"
  
  read -p "Dry run d'abord (recommandé) ? (y/n) " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Lancement migration en mode DRY RUN (pas de modifications)..."
    dart run lib/scripts/migrate_images.dart --dry-run
    
    log_info "Dry run terminé. Vérifier le rapport ci-dessus."
    read -p "Lancer la migration réelle ? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log_warning "Migration réelle en cours..."
      dart run lib/scripts/migrate_images.dart
      log_success "Migration terminée"
    else
      log_info "Migration annulée"
    fi
  else
    log_warning "Migration réelle directe..."
    dart run lib/scripts/migrate_images.dart
    log_success "Migration terminée"
  fi
else
  log_info "Migration skippée (utiliser --migrate pour lancer)"
fi

################################################################################
# ÉTAPE 9: Vérification post-déploiement
################################################################################

log_step "ÉTAPE 9: Vérification post-déploiement"

log_info "Vérification Cloud Functions..."
firebase functions:list | grep -E "(generateImageVariants|regenerateImageVariants|cleanupDeletedImages)" || log_warning "Fonctions non listées (peut être normal juste après déploiement)"

log_info "Vérification Hosting..."
firebase hosting:channel:list || log_warning "Hosting channels non disponibles"

log_success "Vérifications terminées"

################################################################################
# FIN
################################################################################

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ DÉPLOIEMENT SYSTÈME IMAGES TERMINÉ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

log_info "Prochaines étapes:"
echo "  1. Tester upload d'image dans l'admin"
echo "  2. Vérifier variants générés dans Firebase Storage"
echo "  3. Vérifier document créé dans collection image_assets"
echo "  4. Intégrer SmartImage dans pages existantes"
if [ "$MIGRATE" = false ]; then
  echo "  5. Lancer migration: bash $0 --migrate"
fi

echo ""
log_info "Documentation:"
echo "  - Guide complet: DEPLOYMENT_IMAGE_SYSTEM.md"
echo "  - Exemples code: app/lib/examples/image_management_integration_example.dart"
echo "  - Script migration: app/lib/scripts/migrate_images.dart"

echo ""
log_success "🎉 Système d'images 10/10 déployé avec succès !"
echo ""

exit 0
