#!/bin/bash
# Step 3: Monitor Firebase Functions Logs
# Real-time monitoring of promo code validation and checkout functions
# Usage: bash monitor_promo_functions.sh

set -e

PROJECT_ID="maslive"

echo "==============================================="
echo "3️⃣  FIREBASE FUNCTIONS MONITORING"
echo "==============================================="
echo ""

echo "Project: $PROJECT_ID"
echo ""

# Check if firebase CLI is available
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found"
    echo "Install: npm install -g firebase-tools"
    exit 1
fi

# Check if user is authenticated
if ! firebase projects:list --project=$PROJECT_ID &>/dev/null; then
    echo "❌ Not authenticated to Firebase"
    echo "Run: firebase login"
    exit 1
fi

echo "📊 MONITORING OPTIONS:"
echo ""
echo "[1] Watch validatePromoCode() logs (real-time)"
echo "[2] Watch createMixedCartPaymentIntent() logs (real-time)"
echo "[3] Watch ALL promo-related logs (real-time)"
echo "[4] View last 50 validatePromoCode logs (history)"
echo "[5] View last 50 createMixedCartPaymentIntent logs (history)"
echo "[6] Search for errors (last 100 logs)"
echo "[7] Exit"
echo ""

read -p "Select option (1-7): " choice

case $choice in
    1)
        echo ""
        echo "🔴 LIVE: validatePromoCode() - Press Ctrl+C to exit"
        echo ""
        firebase functions:logs read validatePromoCode --limit 30 --project=$PROJECT_ID --follow
        ;;
    2)
        echo ""
        echo "🔴 LIVE: createMixedCartPaymentIntent() - Press Ctrl+C to exit"
        echo ""
        firebase functions:logs read createMixedCartPaymentIntent --limit 30 --project=$PROJECT_ID --follow
        ;;
    3)
        echo ""
        echo "🔴 LIVE: All promo functions - Press Ctrl+C to exit"
        echo ""
        firebase functions:logs read --limit 50 --project=$PROJECT_ID --follow 2>&1 | grep -E "(validatePromoCode|createMixedCart|promo)" || true
        ;;
    4)
        echo ""
        echo "📋 HISTORY: validatePromoCode() - Last 50 logs"
        echo ""
        firebase functions:logs read validatePromoCode --limit 50 --project=$PROJECT_ID
        echo ""
        ;;
    5)
        echo ""
        echo "📋 HISTORY: createMixedCartPaymentIntent() - Last 50 logs"
        echo ""
        firebase functions:logs read createMixedCartPaymentIntent --limit 50 --project=$PROJECT_ID
        echo ""
        ;;
    6)
        echo ""
        echo "🔍 ERRORS: Searching last 100 logs for errors..."
        echo ""
        firebase functions:logs read --limit 100 --project=$PROJECT_ID 2>&1 | grep -i -E "(error|failed|exception|FAILED)" || echo "✅ No errors found"
        echo ""
        ;;
    7)
        echo "👋 Exiting monitor"
        exit 0
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "==============================================="
echo "Monitoring Dashboard"
echo "==============================================="
echo ""
echo "Full Console: https://console.firebase.google.com/project/$PROJECT_ID/functions/logs"
echo ""
