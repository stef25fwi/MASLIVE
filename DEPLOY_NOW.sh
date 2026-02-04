#!/bin/bash

# 🚀 SCRIPT DÉPLOIEMENT FINAL - GROUP TRACKING SYSTEM
# Exécute les 3 déploiements Firebase nécessaires

echo "════════════════════════════════════════════════════════════"
echo "🚀 DÉPLOIEMENT FINAL GROUP TRACKING SYSTEM"
echo "════════════════════════════════════════════════════════════"
echo ""

# Vérifications basiques
echo "📋 Vérifications préalables..."

# Check Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI non trouvé. Installer: npm install -g firebase-tools"
    exit 1
fi
echo "✅ Firebase CLI trouvé"

# Check .firebaserc
if [ ! -f ".firebaserc" ]; then
    echo "❌ .firebaserc non trouvé"
    exit 1
fi
echo "✅ .firebaserc trouvé"

# Check fichiers
if [ ! -f "functions/group_tracking.js" ]; then
    echo "❌ functions/group_tracking.js non trouvé"
    exit 1
fi
echo "✅ Cloud Function trouvée"

if [ ! -f "firestore.rules" ]; then
    echo "❌ firestore.rules non trouvée"
    exit 1
fi
echo "✅ Firestore Rules trouvées"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "DÉPLOIEMENT EN COURS..."
echo "════════════════════════════════════════════════════════════"
echo ""

# 1. Cloud Function
echo "1️⃣  Déployer Cloud Function..."
firebase deploy --only functions:calculateGroupAveragePosition
if [ $? -ne 0 ]; then
    echo "❌ Erreur Cloud Function"
    exit 1
fi
echo "✅ Cloud Function déployée"
echo ""

# 2. Firestore Rules
echo "2️⃣  Déployer Firestore Rules..."
firebase deploy --only firestore:rules
if [ $? -ne 0 ]; then
    echo "❌ Erreur Firestore Rules"
    exit 1
fi
echo "✅ Firestore Rules déployées"
echo ""

# 3. Storage Rules
echo "3️⃣  Déployer Storage Rules..."
firebase deploy --only storage
if [ $? -ne 0 ]; then
    echo "❌ Erreur Storage Rules"
    exit 1
fi
echo "✅ Storage Rules déployées"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "✨ DÉPLOIEMENT RÉUSSI! ✨"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📊 Résumé:"
echo "  ✅ Cloud Function: calculateGroupAveragePosition"
echo "  ✅ Firestore Rules: Tous les collections sécurisées"
echo "  ✅ Storage Rules: Uploads sécurisés"
echo ""
echo "🧪 Next: Tester l'app"
echo "  1. /group-admin → vérifier code 6 chiffres"
echo "  2. /group-tracker → entrer code → se rattacher"
echo "  3. Simuler GPS → vérifier positions Firestore"
echo "  4. /group-live → vérifier marqueur"
echo ""
echo "📝 Logs: firebase functions:log --limit=50"
echo ""
