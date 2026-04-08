#!/bin/bash
# Installation et déploiement des Cloud Functions avec Stripe

set -euo pipefail

echo "🔧 Installation des dépendances Cloud Functions..."
cd /workspaces/MASLIVE/functions
npm install

echo ""
echo "✅ Dépendances installées !"
echo ""
echo "⚠️  Configuration requise : secrets Stripe dans Firebase Secret Manager"
echo ""
echo "Comment obtenir tes clés Stripe :"
echo "  1. Va sur https://dashboard.stripe.com/apikeys"
echo "  2. Copie la Secret key (commence par sk_test_ ou sk_live_)"
echo "  3. Si tu actives les webhooks, copie aussi le Signing secret (whsec_...)"
echo ""
echo "📝 La CLI Firebase va maintenant te demander STRIPE_SECRET_KEY."
cd /workspaces/MASLIVE
firebase functions:secrets:set STRIPE_SECRET_KEY

echo ""
read -r -p "Configurer aussi STRIPE_WEBHOOK_SECRET maintenant ? [y/N] " CONFIGURE_WEBHOOK

if [[ "$CONFIGURE_WEBHOOK" =~ ^[Yy]$ ]]; then
    echo ""
    echo "📝 La CLI Firebase va maintenant te demander STRIPE_WEBHOOK_SECRET."
    firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
fi

echo "✅ Secrets Stripe enregistrés !"
echo ""
echo "🚀 Déploiement des Cloud Functions..."
firebase deploy --only functions

echo ""
echo "✅ Déploiement terminé !"
echo ""
echo "🔗 Fonctions Stripe mises à jour :"
echo "   createStorexPaymentIntent"
echo "   createMixedCartPaymentIntent"
echo "   createMediaMarketplaceCheckout"
echo "   createPhotographerSubscriptionCheckoutSession"
echo "   stripeWebhook"
echo ""
echo "🧪 Tu peux maintenant tester :"
echo "   - Media / premium web : checkout Stripe externe"
echo "   - Merch / mixed mobile : PaymentSheet natif"
echo ""
echo "📊 Vérifie les logs :"
echo "   firebase functions:log"
