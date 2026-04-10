#!/bin/bash
# Installation et déploiement des Cloud Functions avec Stripe

set -euo pipefail

upsert_env_value() {
    local env_file="$1"
    local key="$2"
    local value="$3"

    mkdir -p "$(dirname "$env_file")"
    touch "$env_file"

    if grep -q "^${key}=" "$env_file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        printf '%s=%s\n' "$key" "$value" >> "$env_file"
    fi
}

prompt_and_save_env() {
    local prompt_label="$1"
    local env_key="$2"
    local target_file="$3"

    read -r -p "$prompt_label" env_value
    if [[ -z "$env_value" ]]; then
        return 0
    fi

    upsert_env_value "$target_file" "$env_key" "$env_value"
}

ROOT_ENV_FILE="/workspaces/MASLIVE/.env"
FUNCTIONS_ENV_FILE="/workspaces/MASLIVE/functions/.env"

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
echo "⚙️  Configuration des variables runtime Stripe non secrètes"
echo "   - functions/.env : prix runtime Functions"
echo "   - .env racine      : price IDs premium pour le build web"
echo ""

read -r -p "Configurer les price IDs Premium web maintenant ? [y/N] " CONFIGURE_PREMIUM
if [[ "$CONFIGURE_PREMIUM" =~ ^[Yy]$ ]]; then
    echo ""
    prompt_and_save_env "STRIPE_PREMIUM_MONTHLY_PRICE_ID (price_...) : " "STRIPE_PREMIUM_MONTHLY_PRICE_ID" "$FUNCTIONS_ENV_FILE"
    prompt_and_save_env "STRIPE_PREMIUM_YEARLY_PRICE_ID (price_...) : " "STRIPE_PREMIUM_YEARLY_PRICE_ID" "$FUNCTIONS_ENV_FILE"
    if grep -q '^STRIPE_PREMIUM_MONTHLY_PRICE_ID=' "$FUNCTIONS_ENV_FILE" 2>/dev/null; then
        upsert_env_value "$ROOT_ENV_FILE" "STRIPE_PREMIUM_MONTHLY_PRICE_ID" "$(grep '^STRIPE_PREMIUM_MONTHLY_PRICE_ID=' "$FUNCTIONS_ENV_FILE" | head -n1 | cut -d'=' -f2-)"
    fi
    if grep -q '^STRIPE_PREMIUM_YEARLY_PRICE_ID=' "$FUNCTIONS_ENV_FILE" 2>/dev/null; then
        upsert_env_value "$ROOT_ENV_FILE" "STRIPE_PREMIUM_YEARLY_PRICE_ID" "$(grep '^STRIPE_PREMIUM_YEARLY_PRICE_ID=' "$FUNCTIONS_ENV_FILE" | head -n1 | cut -d'=' -f2-)"
    fi
fi

echo ""
read -r -p "Configurer les price IDs Restaurant Live Tables maintenant ? [y/N] " CONFIGURE_LIVE_TABLES
if [[ "$CONFIGURE_LIVE_TABLES" =~ ^[Yy]$ ]]; then
    echo ""
    prompt_and_save_env "STRIPE_PRICE_FOOD_PRO_LIVE_MONTHLY (price_...) : " "STRIPE_PRICE_FOOD_PRO_LIVE_MONTHLY" "$FUNCTIONS_ENV_FILE"
    prompt_and_save_env "STRIPE_PRICE_FOOD_PRO_LIVE_ANNUAL (price_...) : " "STRIPE_PRICE_FOOD_PRO_LIVE_ANNUAL" "$FUNCTIONS_ENV_FILE"
    prompt_and_save_env "STRIPE_PRICE_FOOD_PREMIUM_MONTHLY (price_...) : " "STRIPE_PRICE_FOOD_PREMIUM_MONTHLY" "$FUNCTIONS_ENV_FILE"
    prompt_and_save_env "STRIPE_PRICE_FOOD_PREMIUM_ANNUAL (price_...) : " "STRIPE_PRICE_FOOD_PREMIUM_ANNUAL" "$FUNCTIONS_ENV_FILE"
    prompt_and_save_env "STRIPE_PRICE_RESTAURANT_LIVE_PLUS_MONTHLY (price_...) : " "STRIPE_PRICE_RESTAURANT_LIVE_PLUS_MONTHLY" "$FUNCTIONS_ENV_FILE"
    prompt_and_save_env "STRIPE_PRICE_RESTAURANT_LIVE_PLUS_ANNUAL (price_...) : " "STRIPE_PRICE_RESTAURANT_LIVE_PLUS_ANNUAL" "$FUNCTIONS_ENV_FILE"
fi

echo ""
echo "💡 Option mobile natif"
echo "   Les flows PaymentSheet natifs utilisent STRIPE_PUBLISHABLE_KEY au build mobile :"
echo "   flutter build apk --release --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_..."
read -r -p "Enregistrer aussi STRIPE_PUBLISHABLE_KEY dans .env racine ? [y/N] " CONFIGURE_PUBLISHABLE
if [[ "$CONFIGURE_PUBLISHABLE" =~ ^[Yy]$ ]]; then
    echo ""
    prompt_and_save_env "STRIPE_PUBLISHABLE_KEY (pk_test_... / pk_live_...) : " "STRIPE_PUBLISHABLE_KEY" "$ROOT_ENV_FILE"
fi
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
echo "   - Dashboard admin → Test Stripe : rapport de préparation complet"
echo "   - Storex web / mixed web / media / premium / live tables : checkout Stripe externe"
echo "   - Storex mobile / mixed mobile : PaymentSheet natif"
echo ""
echo "📊 Vérifie les logs :"
echo "   firebase functions:log"
