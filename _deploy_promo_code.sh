#!/bin/bash
# Deploy Promo Code System
# Complete: git add/commit/push + Firebase Functions deploy
# Usage: bash _deploy_promo_code.sh

set -e

echo "==============================================="
echo "🎟️  PROMO CODE SYSTEM DEPLOYMENT"
echo "==============================================="
echo ""

# [1/6] Git Add
echo "[1/6] 📝 Staging files..."
git add -A
echo "✅ Files staged"
echo ""

# [2/6] Git Commit
echo "[2/6] 💾 Committing changes..."
COMMIT_MSG="feat(checkout): server-side promo code validation + UI integration

- New CF: validatePromoCode() callable validates codes from Firestore config
- Modified CF: createMixedCartPaymentIntent() accepts & applies promoCode
- Added CartCheckoutService.validatePromoCode() method
- Updated maslive_ultra_premium_checkout_page.dart with async promo validation
- Added UI loading state + error messages during code validation
- Includes promo info in Stripe metadata + Firestore order audit trail
- Server-side discount calculation (secure)
- Comprehensive documentation + unit tests provided

Documentation:
- PROMO_CODE_SUMMARY.md (architecture + examples)
- PROMO_CODE_IMPLEMENTATION.md (technical details)
- PROMO_CODE_DEPLOYMENT.md (deployment checklist)
- PROMO_CODE_QUICK_START.txt (3-step guide)
- functions/promo-code.test.js (unit tests)
- CHANGELOG_PROMO_CODE.md (change details)"

git commit -m "$COMMIT_MSG"
echo "✅ Changes committed"
echo ""

# [3/6] Git Push
echo "[3/6] 🚀 Pushing to remote..."
git push origin main
echo "✅ Pushed to main branch"
echo ""

# [4/6] Firebase Functions Deploy
echo "[4/6] ⚡ Deploying Cloud Functions..."
firebase deploy --only functions --project=maslive
echo "✅ Functions deployed"
echo ""

# [5/6] Summary
echo "==============================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "==============================================="
echo ""
echo "📍 What was deployed:"
echo "  ✓ validatePromoCode() callable"
echo "  ✓ createMixedCartPaymentIntent() updated"
echo "  ✓ CartCheckoutService enhanced"
echo "  ✓ Checkout UI integrated"
echo ""

echo "📋 Next Steps (IMPORTANT):"
echo "  1️⃣  Create Firestore document:"
echo "      Collection: 'config'"
echo "      Document: 'promo_codes'"
echo "      See: PROMO_CODE_QUICK_START.txt"
echo ""
echo "  2️⃣  Test E2E:"
echo "      - Valid code: MAS10"
echo "      - Invalid code: FAKECODE"
echo "      - Min order: €50 required"
echo ""
echo "  3️⃣  Monitor Functions logs:"
echo "      firebase functions:logs read validatePromoCode --limit 50"
echo ""

echo "📚 Documentation:"
echo "  • Quick start: PROMO_CODE_QUICK_START.txt"
echo "  • Full guide: PROMO_CODE_IMPLEMENTATION.md"
echo "  • Deployment: PROMO_CODE_DEPLOYMENT.md"
echo ""

echo "Project Console:"
echo "  https://console.firebase.google.com/project/maslive/overview"
echo ""
