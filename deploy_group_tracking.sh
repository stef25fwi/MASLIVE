#!/bin/bash

# 🚀 SCRIPT DÉPLOIEMENT FINAL - GROUP TRACKING SYSTEM
# Déploie Cloud Functions + Firestore Rules + Storage Rules

set -e

echo "════════════════════════════════════════════════════════════"
echo "🚀 DÉPLOIEMENT SYSTÈME GROUP TRACKING"
echo "════════════════════════════════════════════════════════════"
echo ""

# Vérifications préalables
echo "✓ Vérification de Firebase CLI..."
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI non trouvé. Installer avec: npm install -g firebase-tools"
    exit 1
fi

echo "✓ Vérification de la configuration Firebase..."
if [ ! -f ".firebaserc" ]; then
    echo "❌ Fichier .firebaserc non trouvé"
    exit 1
fi

echo "✓ Vérification des fichiers..."
if [ ! -f "functions/index.js" ] || [ ! -f "functions/group_tracking.js" ]; then
    echo "❌ Cloud Functions files not found"
    exit 1
fi

if [ ! -f "firestore.rules" ]; then
    echo "❌ firestore.rules not found"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "ÉTAPE 1️⃣ : Déployer Cloud Function"
echo "════════════════════════════════════════════════════════════"
echo ""

firebase deploy --only functions:calculateGroupAveragePosition

if [ $? -eq 0 ]; then
    echo "✅ Cloud Function déployée avec succès!"
else
    echo "❌ Erreur lors du déploiement Cloud Function"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "ÉTAPE 2️⃣ : Déployer Firestore Rules"
echo "════════════════════════════════════════════════════════════"
echo ""

firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo "✅ Firestore Rules déployées avec succès!"
else
    echo "❌ Erreur lors du déploiement Firestore Rules"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "ÉTAPE 3️⃣ : Déployer Storage Rules"
echo "════════════════════════════════════════════════════════════"
echo ""

firebase deploy --only storage

if [ $? -eq 0 ]; then
    echo "✅ Storage Rules déployées avec succès!"
else
    echo "❌ Erreur lors du déploiement Storage Rules"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✨ DÉPLOIEMENT COMPLET!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📋 Résumé:"
echo "  ✅ Cloud Function: calculateGroupAveragePosition"
echo "  ✅ Firestore Rules: group_* collections"
echo "  ✅ Storage Rules: group_shops/* uploads"
echo ""
echo "📝 Next Steps:"
echo "  1. Vérifier les logs: firebase functions:log --limit=50"
echo "  2. Tester Admin creation: /group-admin"
echo "  3. Tester Tracker linking: /group-tracker"
echo "  4. Tester GPS tracking: Start tracking"
echo "  5. Vérifier carte live: /group-live"
echo ""
echo "🎯 Tous les tests sont dans FINAL_DEPLOYMENT_CHECKLIST.md"
echo ""
