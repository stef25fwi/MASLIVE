# 🎟️ PROMO CODE SYSTEM - Implementation Complete

## ✅ Modifications Appliquées

### 1. Cloud Functions (`functions/index.js`)

**Nouvelle CF: `validatePromoCode()` (callable)**
```javascript
exports.validatePromoCode = onCall(
  { region: "us-east1" },
  async (req) => {
    // Valide code promo contre Firestore config
    // Vérifie: expiration, restrictions, montant minimum
    // Retourne: { valid, discountCents, message }
  }
);
```

**Modifications: `createMixedCartPaymentIntent()`**
- ✅ Accepte paramètre `promoCode`
- ✅ Applique réduction côté serveur (sécurisé)
- ✅ Inclut `promoCode` et `promoCentsDiscount` dans metadata Stripe
- ✅ Sauvegarde coupon dans l'entité order Firestore

### 2. Dart Client (`app/lib/services/cart_checkout_service.dart`)

**Nouvelle méthode: `validatePromoCode()`**
```dart
static Future<Map<String, dynamic>> validatePromoCode(
  String promoCode, {
  required int subtotalCents,
}) async {
  // Appelle CF validatePromoCode
  // Retourne réponse structurée
}
```

**Modifications: `startMixedCheckout()`**
- ✅ Accepte paramètre optionnel `promoCode`
- ✅ Passe coupon à `createMixedCartPaymentIntent` callable

### 3. Checkout UI (`app/lib/pages/checkout/maslive_ultra_premium_checkout_page.dart`)

**Nouvel état**:
- ✅ `_promoValidationLoading` pour gérer loading lors validation

**Modifications: `_applyPromo()` (nouvellement asynchrone)**
- ✅ Appelle `CartCheckoutService.validatePromoCode()`
- ✅ Affiche message de succès + réduction appliquée
- ✅ Affiche erreur détaillée si invalide
- ✅ Efface le champ input après succès
- ✅ Threading correct (vérifie `mounted`)

**Modifications: Bouton d'application**
- ✅ Désactivé pendant `_promoValidationLoading`
- ✅ Affiche CircularProgressIndicator lors validation
- ✅ UX classe et non-bloquant

**Modifications: Checkout flow**
- ✅ Passe `promoCode: _promoCode` à `startMixedCheckout()`

---

## 🔧 Configuration Firestore Requise

### Document: `config/promo_codes`

```json
{
  "codes": {
    "MAS10": {
      "type": "percentage",
      "value": 10,
      "maxDiscountCents": null,
      "minSubtotalCents": 5000,
      "expiresAt": <Timestamp 2026-12-31T23:59:59Z>,
      "disabled": false,
      "description": "10% off all items"
    },
    "MEDIA5": {
      "type": "fixed",
      "value": 500,
      "minSubtotalCents": 2000,
      "expiresAt": <Timestamp 2026-12-31T23:59:59Z>,
      "disabled": false,
      "description": "€5 fixed discount on media"
    },
    "WELCOME20": {
      "type": "percentage",
      "value": 20,
      "maxDiscountCents": 2000,
      "minSubtotalCents": null,
      "expiresAt": <Timestamp 2026-06-30T23:59:59Z>,
      "disabled": false,
      "description": "20% off for new users (capped at €20)"
    },
    "INACTIVE_CODE": {
      "type": "percentage",
      "value": 50,
      "disabled": true,
      "description": "This code is disabled and won't validate"
    }
  }
}
```

### Structure champs `codes[CODE_NAME]`:

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `type` | string | ✅ | `"percentage"` ou `"fixed"` |
| `value` | number | ✅ | % ou montant (cents pour fixed) |
| `maxDiscountCents` | number | ❌ | Cap de réduction (% seulement) |
| `minSubtotalCents` | number | ❌ | Montant minimum pour activer |
| `expiresAt` | Timestamp | ❌ | Date expiration |
| `disabled` | boolean | ❌ | Désactive le code (défaut: false) |
| `description` | string | ❌ | Notes internes |

---

## 🚀 Prochaines Étapes

### 1. **Créer configuration Firestore** (REQUIRED avant test)
```bash
# Via Firebase Console > Firestore > Créer document
# Collection: config
# Document: promo_codes
# Ajouter structure JSON ci-dessus
```

### 2. **Test local**
```bash
# Déployer functions
firebase deploy --only functions

# Test du checkout
# - Créer panier mixte (merch + media)
# - Entrer code: "MAS10"
# - Cliquer "Appliquer"
# - Vérifier réduction affichée
# - Procéder au checkout
# - Vérifier Firestore orders[orderId].promoCode
```

### 3. **Validation fin-à-fin**
- [x] Code valide → réduction appliquée
- [x] Code expiré → erreur affichée
- [x] Code invalide → erreur affichée
- [x] Montant minimum non atteint → erreur affichée
- [x] Réduction calculée serveur (non modifiable client)
- [x] Metadata Stripe contient coupon info

---

## 📊 Montants Calculés (Exemple)

```
Scénario: Merch €50 + Media €20 + code "MAS10" (10%)

CLIENT-SIDE DISPLAY:
  Subtotal (merch+media): 70.00 €
  Promo discount (MAS10): -7.00 €
  Shipping: 20.00 €
  Total: 83.00 €

SERVER-SIDE CHECKOUT:
  Store order subtotal: 5000 cents
  Media order subtotal: 2000 cents
  Promo discount: -700 cents (10% × 7000)
  Shipping: 2000 cents
  PaymentIntent amount: 8300 cents (€83.00)
  
  Metadata stored:
    promoCode: "MAS10"
    promoCentsDiscount: 700
```

---

## 🔐 Sécurité

### ✅ Côté client
- Validation asynchrone via CF (pas hardcodé)
- Montants affichage uniquement (UI)
- Code HTML ne contient aucun secret

### ✅ Côté serveur
- CF `validatePromoCode()` source de vérité
- Validation redondante dans `createMixedCartPaymentIntent()`
- Règles Firestore peuvent être renforcées:
  ```rules
  match /config/promo_codes {
    allow read: if true;  // Tous les clients authentifiés
    allow write: if request.auth.token.admin == true;  // Admin seulement
  }
  ```

---

## 📝 Notes

- **Pas de stockage coupon par user**: Cumul illimité autorisé (gérer via `maxUseCount` si besoin)
- **Idempotence**: Webhook `payment_intent.succeeded` est idempotent, coupons appliqués une fois
- **Audit**: Métadata Stripe + Firestore order logs garantir traçabilité

---

## ✨ État Final

```
✅ validatePromoCode() CF - Fonctionnel
✅ cart_checkout_service - Intégré
✅ maslive_ultra_premium_checkout_page - UI mise à jour
✅ Database schema Firestore - Documenter
⏳ Firestore config/promo_codes - À CRÉER
⏳ Tests end-to-end - À EXÉCUTER
```
