#!/bin/bash

# Nettoyer l'historique Git des secrets Stripe exposés
# Utilise git filter-branch pour supprimer la clé de tous les commits

set -e

echo "🔧 Nettoyage de l'historique Git (git filter-branch)"
echo "======================================================"

cd /workspaces/MASLIVE

# Vérifier le statut
echo ""
echo "📋 Statut actuel :"
git log --oneline -5

echo ""
echo "⚠️  Cet outil va modifier l'historique Git."
echo "    Les commits auront des IDs différents."
echo "    Les autres collaborateurs devront faire : git pull --rebase"
echo ""
read -p "Continuer ? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Annulé."
    exit 1
fi

echo ""
echo "🔍 Étape 1: Identifier la clé à supprimer..."
# La clé est dans les fichiers avant modification
SECRET_KEY="sk_test_51Ssn0PCCIRtTE2nOkwOarKnrKijY1ejL54rugQOlxj0G0B4gb9ue202bHhPbDtoBQJcX74UB4xf31Jj8EHzmAA9P00NfLX4t6t"

echo "❌ Clé à supprimer de l'historique :"
echo "   ${SECRET_KEY:0:20}...${SECRET_KEY: -10}"

echo ""
echo "🔨 Étape 2: Exécuter git filter-branch..."

git filter-branch --force --tree-filter \
  "find . -type f \( -name '*.md' -o -name '*.txt' \) -exec sed -i \"s|$SECRET_KEY|sk_test_YOUR_ACTUAL_KEY_FROM_STRIPE_DASHBOARD|g\" {} + 2>/dev/null || true" \
  -- --all

echo ""
echo "✅ Nettoyage terminé !"

echo ""
echo "🔄 Étape 3: Force push (attention !)"
echo "   Cela réécrit l'historique sur GitHub."
echo "   Les autres devront faire : git pull --rebase"
echo ""
read -p "Faire le force push ? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "⏸️  Force push non exécuté."
    echo "   Si vous changez d'avis, exécutez :"
    echo "   git push --force-with-lease origin main"
    exit 1
fi

git push --force-with-lease origin main

echo ""
echo "✅ Push réussi !"
echo "   L'historique a été nettoyé."
echo "   Les collaborateurs doivent faire : git pull --rebase"
