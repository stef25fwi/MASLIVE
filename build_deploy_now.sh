#!/bin/bash
set -e

echo "📱 Building Flutter web app..."
cd /workspaces/MASLIVE/app
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
flutter build web --release --no-wasm-dry-run --dart-define=MAPBOX_ACCESS_TOKEN="$TOKEN" "${STRIPE_PREMIUM_ARGS[@]}"

echo "🚀 Deploying to Firebase hosting..."
cd /workspaces/MASLIVE
firebase deploy --only hosting

echo "✅ Build and deploy completed!"
