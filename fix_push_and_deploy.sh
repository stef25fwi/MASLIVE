#!/bin/bash

# Fix GitHub Push Protection - Relancer le push après correction

set -e

echo "🔐 Fix GitHub Push Protection"
echo "=============================="

cd /workspaces/MASLIVE

echo ""
echo "📋 Étape 1: Ajouter les fichiers corrigés"
git add COPY_PASTE_COMMANDS.md START_HERE_V21_STRIPE.md .gitignore

echo "✅ Fichiers ajoutés"

echo ""
echo "💾 Étape 2: Créer un commit de correction"
git commit -m "security: remove exposed Stripe test keys from documentation + strengthen .gitignore" || echo "⚠️  Aucun changement à committer (déjà fait)"

echo ""
echo "📤 Étape 3: Pusher vers origin/main"
git push origin main

echo ""
echo "✅ Push réussi !"
echo ""
echo "🎯 Prochaines étapes :"
echo "  1. flutter build web --release"
echo "  2. firebase deploy --only hosting,functions,firestore:rules,firestore:indexes"
