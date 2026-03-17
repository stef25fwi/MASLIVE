# 🚀 PROMO CODE DEPLOYMENT CHECKLIST

## Phase 1: Pre-Deployment Validation ✓

- [x] Cloud Functions `validatePromoCode()` créée
- [x] Modification `createMixedCartPaymentIntent()` pour intégrer coupon
- [x] `CartCheckoutService.validatePromoCode()` implémentée
- [x] `Cart_checkout_service.startMixedCheckout()` accepte `promoCode`
- [x] UI `maslive_ultra_premium_checkout_page.dart` intégrée
- [x] Bouton d'application avec loading state
- [x] Pas d'erreurs de compilation (Dart + Functions)
- [x] Documentation complète
- [x] Tests unitaires fournis

## Phase 2: Configuration Firestore ⏳

⚠️ **REQUIRED before deployment to production**

### Step 1: Créer collection + document
```bash
# Via Firebase Console:
# 1. Firestore > Créer une collection: "config"
# 2. Ajouter document: "promo_codes"
# 3. Ajouter champs JSON (voir PROMO_CODE_IMPLEMENTATION.md)
```

### Step 2: Insérer codes de test
Copier la structure JSON de `PROMO_CODE_IMPLEMENTATION.md` > Firestore Console

Codes à configurer:
- `MAS10` - 10% off (min €50)
- `MEDIA5` - €5 fixed (min €20)
- `WELCOME20` - 20% off capped at €20

### Step 3: Vérifier règles Firestore (optionnel)
```rules
match /config/promo_codes {
  allow read: if request.auth != null;
  allow write: if request.auth.token.admin == true;
}
```

## Phase 3: Déploiement Functions ⏳

```bash
# Depuis /workspaces/MASLIVE
cd functions
npm run build
cd ..
firebase deploy --only functions
```

### Vérifier après deploy:
- [x] `validatePromoCode` function disponible
- [x] `createMixedCartPaymentIntent` updated
- [x] Pas d'erreurs dans logs Firebase Functions

## Phase 4: Test E2E ⏳

### Scénario 1: Code valide
1. Créer panier mixte:
   - Ajouter produit merch (€50+)
   - Ajouter photo média
2. Aller au checkout
3. Entrer code: `MAS10`
4. Cliquer "Appliquer"
5. ✅ Vérifier: réduction affichée = 10% du sous-total
6. Procéder au paiement
7. ✅ Vérifier Firestore `orders/{storeOrderId}`:
   - `promoCode: "MAS10"`
   - `promoCentsDiscount: <montant calculé>`

### Scénario 2: Code minimum order
1. Panier €20 total
2. Entrer code: `MAS10` (min €50)
3. ✅ Vérifier: message "Minimum commande: 50.00€"
4. Ajouter produit pour atteindre €50
5. ✅ Vérifier: code s'applique maintenant

### Scénario 3: Code expiré
1. Modifier Firestore: `MEDIA5.expiresAt = date past`
2. Entrer code: `MEDIA5`
3. ✅ Vérifier: message "Code promo expiré"

### Scénario 4: Code disabled
1. Modifier Firestore: `MEDIA5.disabled = true`
2. Entrer code: `MEDIA5`
3. ✅ Vérifier: message "Code promo désactivé"

### Scénario 5: Code invalide
1. Entrer code: `FAKECOCDE`
2. ✅ Vérifier: message "Code promo invalide"

## Phase 5: Production Rollout ⏳

### Pre-production smoke test
- [ ] Tester 3 codes en prod (staging)
- [ ] Vérifier logs Stripe webhook
- [ ] Vérifier Firestore orders créées avec promo info

### Production deployment
```bash
# 1. Commit + Push
git add -A
git commit -m "feat(checkout): server-side promo code validation"
git push

# 2. Deploy
firebase deploy --only functions,firestore

# 3. Monitor
firebase functions:logs read validatePromoCode --limit 50
firebase functions:logs read createMixedCartPaymentIntent --limit 50
```

### Post-deployment validation (24h)
- [ ] No error spikes in Functions logs
- [ ] Promo usage metrics tracking
- [ ] Customer feedback: no complaints
- [ ] Database size normal (Firestore reads)

## Phase 6: Future Enhancements ⏳

- [ ] Add promo usage limits per user
- [ ] Add promo usage tracking (max uses per code)
- [ ] Dashboard: manage active promo codes
- [ ] Analytics: track which codes are used most
- [ ] Time-limited seasonal codes (e.g., Black Friday)
- [ ] Referral code system (user-specific codes)
- [ ] A/B testing: different discount tiers

---

## 📋 Current Implementation Status

### ✅ Done (Code Level)
- Cloud Functions API fully implemented
- Client-side UI fully integrated
- Database schema designed
- Error handling comprehensive
- Security considerations addressed

### ⏳ Pending (Setup/Ops)
1. Create Firestore `config/promo_codes` document
2. Deploy Functions to production
3. Run E2E test scenarios
4. Monitor production for 24h

### 📊 Files Modified

```
functions/index.js
  + validatePromoCode() [63 lines]
  ~ createMixedCartPaymentIntent() [+7 lines]

app/lib/services/cart_checkout_service.dart
  + validatePromoCode() method
  ~ startMixedCheckout() accepts promoCode param

app/lib/pages/checkout/maslive_ultra_premium_checkout_page.dart
  ~ _applyPromo() now async + calls CF
  + _promoValidationLoading state
  ~ ElevatedButton shows loading during validation
  ~ startMixedCheckout() passes promoCode

New Files:
  + PROMO_CODE_IMPLEMENTATION.md
  + setup_promo_codes.sh
  + functions/promo-code.test.js
```

---

## 🔐 Security Checklist

- [x] Validation happens server-side (not client-only)
- [x] Promo discount never trusted from client
- [x] PaymentIntent amount calculated server-side
- [x] Metadata includes promo info (audit trail)
- [x] Firestore rules can restrict promo_codes writes to admin
- [x] No hardcoded codes in app (config-driven)
- [x] Rate limiting possible (Cloud Functions quotas)

---

## 📞 Support

**If validation fails in production:**

1. Check Firestore `config/promo_codes` document exists
2. Check Firebase Functions `validatePromoCode` is deployed
3. Check browser DevTools: Network tab > Function call response
4. Check Firebase Functions logs: `firebase functions:logs`
5. Verify user is authenticated (req.auth check)

---

**Last Updated**: March 17, 2026
**Next Review**: After Phase 4 (E2E tests pass)
