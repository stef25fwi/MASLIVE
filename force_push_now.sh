#!/bin/bash

# Force push après git filter-branch
# Cette commande écrase l'historique GitHub avec la version locale nettoyée

set -e

cd /workspaces/MASLIVE

echo "🔄 Mettre à jour les infos GitHub..."
git fetch origin

echo ""
echo "⚠️  ATTENTION: Ceci va réécrire l'historique sur GitHub"
echo "    Tous les commits auront des IDs différents"
echo "    Les collaborateurs doivent faire: git pull --rebase"
echo ""
read -p "Êtes-vous sûr ? (yes/no) " -r
echo
if [[ ! $REPLY == "yes" ]]; then
    echo "❌ Annulé."
    exit 1
fi

echo ""
echo "📤 Force push vers origin/main..."
git push --force origin main

echo ""
echo "✅ Push réussi !"
echo ""
echo "📢 À communiquer aux autres collaborateurs :"
echo "    git pull --rebase"
echo ""
echo "🚀 Prochaine étape : Flutter build + Firebase deploy"
