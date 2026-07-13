#!/bin/bash
# Déploiement Firebase uniquement

set -e

echo "🌍 DÉPLOIEMENT FIREBASE"
echo "======================="
echo ""

# Build web
echo "[1/3] 🏗️  Build Flutter web..."
cd /workspaces/MASLIVE/app
flutter pub get
{ [ -f /workspaces/MASLIVE/.env ] && source /workspaces/MASLIVE/.env; } 2>/dev/null || true
TOKEN=${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}}
STRIPE_PREMIUM_ARGS=()
if [ -z "$TOKEN" ]; then
	echo "❌ ERREUR: token Mapbox manquant (MAPBOX_ACCESS_TOKEN / MAPBOX_PUBLIC_TOKEN / MAPBOX_TOKEN)."
	echo "➡️  Lance la tâche: MASLIVE: 🗺️ Set Mapbox token (.env) puis relance."
	exit 1
fi
echo "🗺️  Token Mapbox détecté: OK (redacted)"
if [ -n "${STRIPE_PREMIUM_MONTHLY_PRICE_ID:-}" ] && [ -n "${STRIPE_PREMIUM_YEARLY_PRICE_ID:-}" ]; then
	STRIPE_PREMIUM_ARGS+=(--dart-define=STRIPE_PREMIUM_MONTHLY_PRICE_ID="$STRIPE_PREMIUM_MONTHLY_PRICE_ID")
	STRIPE_PREMIUM_ARGS+=(--dart-define=STRIPE_PREMIUM_YEARLY_PRICE_ID="$STRIPE_PREMIUM_YEARLY_PRICE_ID")
	echo "💳 Price IDs premium web détectés: OK (redacted)"
else
	echo "⚠️ Price IDs premium web absents: le paywall web restera en configuration manquante."
fi
# Clé publique Stripe (indispensable pour la PaymentSheet native iOS/Android).
# Sur web le paiement passe par Stripe Checkout (redirection) et n'en a pas besoin,
# mais on transmet la valeur si présente pour un build unifié.
if [ -n "${STRIPE_PUBLISHABLE_KEY:-}" ]; then
	STRIPE_PREMIUM_ARGS+=(--dart-define=STRIPE_PUBLISHABLE_KEY="$STRIPE_PUBLISHABLE_KEY")
	echo "💳 Clé publique Stripe détectée: OK (redacted)"
else
	echo "⚠️ STRIPE_PUBLISHABLE_KEY absente: la PaymentSheet native sera désactivée."
fi
if [ -n "${STRIPE_APPLE_MERCHANT_ID:-}" ]; then
	STRIPE_PREMIUM_ARGS+=(--dart-define=STRIPE_APPLE_MERCHANT_ID="$STRIPE_APPLE_MERCHANT_ID")
fi
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$TOKEN" "${STRIPE_PREMIUM_ARGS[@]}"
cd /workspaces/MASLIVE
echo "✅ Build complété"
echo ""

# Deploy Firestore rules
echo "[2/3] 📋 Deploy Firestore rules..."
firebase deploy --only firestore:rules
echo "✅ Firestore rules déployées"
echo ""

# Deploy hosting + functions
echo "[3/3] 🚀 Deploy hosting et functions..."
firebase deploy --only hosting,functions
echo "✅ Hosting et functions déployés"
echo ""

echo "════════════════════════════"
echo "✅ FIREBASE DÉPLOYÉ!"
echo "════════════════════════════"
