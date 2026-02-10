#!/bin/bash

# 🚀 SCRIPT DE DÉPLOIEMENT AUTOMATISÉ
# Group Tracking System - Firebase Deployment
# Utilisation: chmod +x deploy.sh && ./deploy.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_step() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Main execution
clear

print_header "🚀 DÉPLOIEMENT SYSTÈME GROUP TRACKING"

echo "📋 Vérifications préalables..."
echo ""

# Check 1: Firebase CLI
print_step "Vérification Firebase CLI..."
if command -v firebase &> /dev/null; then
    FIREBASE_VERSION=$(firebase --version | head -1)
    print_success "Firebase CLI trouvé: $FIREBASE_VERSION"
else
    print_error "Firebase CLI non trouvé!"
    echo "Installation: npm install -g firebase-tools"
    exit 1
fi

# Check 2: .firebaserc
print_step "Vérification configuration Firebase..."
if [ -f ".firebaserc" ]; then
    PROJECT=$(grep -o '"default": "[^"]*"' .firebaserc | cut -d'"' -f4)
    print_success "Projet Firebase: $PROJECT"
else
    print_error "Fichier .firebaserc non trouvé!"
    exit 1
fi

# Check 3: Cloud Function files
print_step "Vérification Cloud Function..."
if [ -f "functions/index.js" ] && [ -f "functions/group_tracking.js" ]; then
    print_success "Cloud Function files found"
else
    print_error "Cloud Function files missing!"
    exit 1
fi

# Check 4: Firestore Rules
print_step "Vérification Firestore Rules..."
if [ -f "firestore.rules" ]; then
    RULES_SIZE=$(wc -l < firestore.rules)
    print_success "Firestore Rules trouvées ($RULES_SIZE lines)"
else
    print_error "firestore.rules non trouvé!"
    exit 1
fi

# Check 5: Storage Rules
print_step "Vérification Storage Rules..."
if [ -f "storage.rules" ]; then
    STORAGE_SIZE=$(wc -l < storage.rules)
    print_success "Storage Rules trouvées ($STORAGE_SIZE lines)"
else
    print_error "storage.rules non trouvé!"
    exit 1
fi

echo ""
print_header "✅ TOUTES LES VÉRIFICATIONS RÉUSSIES!"
echo ""

# Confirmation
read -p "📝 Êtes-vous prêt à déployer? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Déploiement annulé"
    exit 0
fi

echo ""
print_header "🚀 DÉPLOIEMENT EN COURS..."

# Deployment 1: Cloud Function
echo ""
print_step "ÉTAPE 1/3: Déployer Cloud Function..."
echo "Commande: firebase deploy --only functions:calculateGroupAveragePosition"
echo ""

if firebase deploy --only functions:calculateGroupAveragePosition; then
    print_success "Cloud Function déployée!"
else
    print_error "Erreur déploiement Cloud Function"
    exit 1
fi

# Deployment 2: Firestore Rules
echo ""
print_step "ÉTAPE 2/3: Déployer Firestore Rules..."
echo "Commande: firebase deploy --only firestore:rules"
echo ""

if firebase deploy --only firestore:rules; then
    print_success "Firestore Rules déployées!"
else
    print_error "Erreur déploiement Firestore Rules"
    exit 1
fi

# Deployment 3: Storage Rules
echo ""
print_step "ÉTAPE 3/3: Déployer Storage Rules..."
echo "Commande: firebase deploy --only storage"
echo ""

if firebase deploy --only storage; then
    print_success "Storage Rules déployées!"
else
    print_error "Erreur déploiement Storage Rules"
    exit 1
fi

# Success summary
echo ""
print_header "🎉 DÉPLOIEMENT RÉUSSI!"

echo ""
echo "📊 Résumé du déploiement:"
echo "  ✅ Cloud Function: calculateGroupAveragePosition"
echo "  ✅ Firestore Rules: Tous les collections sécurisées"
echo "  ✅ Storage Rules: Uploads boutique sécurisés"
echo ""

echo "📝 Next Steps:"
echo ""
echo "1️⃣  Vérifier les logs Cloud Function:"
echo "   firebase functions:log --lines 50"
echo ""
echo "2️⃣  Tester Admin création:"
echo "   - Ouvrir /group-admin"
echo "   - Vérifier code 6 chiffres affiché"
echo ""
echo "3️⃣  Tester Tracker rattachement:"
echo "   - Ouvrir /group-tracker"
echo "   - Entrer le code admin"
echo "   - Vérifier rattachement réussi"
echo ""
echo "4️⃣  Tester GPS tracking:"
echo "   - Simuler position GPS"
echo "   - Vérifier positions écrites Firestore"
echo "   - Vérifier position moyenne calculée"
echo ""
echo "5️⃣  Tests E2E complets:"
echo "   - Consulter: E2E_TESTS_GUIDE.md"
echo "   - 8 tests détaillés avec vérifications"
echo ""

echo "📚 Documentation:"
echo "  • DEPLOY_NOW.md ← Commandes rapides"
echo "  • E2E_TESTS_GUIDE.md ← Tests complets (60 min)"
echo "  • SYSTEM_ARCHITECTURE_VISUAL.md ← Architecture"
echo "  • DEPLOYMENT_COMMANDS.md ← Commandes détaillées"
echo ""

print_success "Déploiement terminé avec succès! 🚀"
echo ""
