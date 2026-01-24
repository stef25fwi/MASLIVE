#!/bin/bash
# Installation et déploiement des Cloud Functions avec Stripe

set -e

echo "🔧 Installation des dépendances Cloud Functions..."
cd /workspaces/MASLIVE/functions
npm install

echo ""
echo "✅ Dépendances installées !"
echo ""
echo "⚠️  Configuration requise : Clé Stripe API"
echo ""
echo "Comment obtenir ta clé Stripe :"
echo "  1. Va sur https://dashboard.stripe.com/apikeys"
echo "  2. Copie ta clé Secret (commence par sk_test_ ou sk_live_)"
echo "  3. Exemple: sk_test_51Ssn0PCCIRtTE2nOkwOarKnrKijY1ejL54rugQOlxj0G0B4gb9ue..."
echo ""
read -p "Entre ta clé Stripe Secret Key : " STRIPE_KEY
echo ""

if [ -z "$STRIPE_KEY" ]; then
    echo "❌ Erreur: Aucune clé fournie"
    exit 1
fi

# Vérifier que la clé commence par sk_test_ ou sk_live_
if ! [[ "$STRIPE_KEY" =~ ^sk_(test|live)_ ]]; then
    echo "❌ Erreur: La clé doit commencer par sk_test_ ou sk_live_"
    exit 1
fi

# Configuration Firebase (méthode sécurisée)
echo ""
echo "📝 Configuration de la clé Stripe dans Firebase..."
firebase functions:config:set stripe.secret_key="$STRIPE_KEY"

echo ""
echo "✅ Configuration Stripe sauvegardée dans Firebase !"
echo ""
echo "🚀 Déploiement des Cloud Functions..."
cd /workspaces/MASLIVE
firebase deploy --only functions

echo ""
echo "✅ Déploiement terminé !"
echo ""
echo "🔗 Fonction déployée :"
echo "   createCheckoutSessionForOrder"
echo ""
echo "🧪 Tu peux maintenant tester le paiement avec une carte de test :"
echo "   Numéro : 4242 4242 4242 4242"
echo "   Date : N'importe quelle date future (ex: 12/25)"
echo "   CVC : 123"
echo ""
echo "📊 Vérifie les logs :"
echo "   firebase functions:log"
