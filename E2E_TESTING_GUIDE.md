# 🧪 E2E Testing Guide - Promo Code System

## Overview

This guide covers 3 mandatory test scenarios for the promo code system:
1. ✅ Valid code applies discount
2. ✅ Minimum order requirement enforced
3. ✅ Invalid code rejected with error

**Prerequisites:**
- ✅ Functions deployed (already done)
- ⏳ Firestore `config/promo_codes` created (Step 1)
- ✅ App built and running on device/emulator

**Duration:** ~10 minutes for all 3 scenarios

---

## Test Environment Setup

### 1. Preparation Checklist

- [ ] Firestore `config/promo_codes` document created with 3 codes
- [ ] App rebuilt/deployed to device
- [ ] Test account ready (with saved shipping address)
- [ ] Network connection active

### 2. Test Data Available

```
MAS10: 10% off (min €50)
MEDIA5: €5 off (min €20)
WELCOME20: 20% off, capped at €20 (no min)
```

---

## Scenario 1: ✅ Valid Promo Code

**Objective**: Validate that a valid code correctly applies discount

### Setup
1. Open app, sign in with test account
2. Add to cart:
   - **Merch item**: €50+ (e.g., 2× €30 products = €60)
   - **Media item**: €20 (e.g., 1× photo pack)
   - **Total**: €80

### Steps

1. **Navigate to Cart**
   - Tap "Panier" tab
   - Verify cart shows:
     - 2 merch items (€60)
     - 1 media item (€20)
     - Total: €80

2. **Go to Checkout**
   - Tap "Commander" → "MASLIVE Checkout"
   - Page displays: "Commande MASLIVE"
   - Summary shows:
     - Sous-total: 80.00 €
     - Réduction: 0,00 €

3. **Apply Promo Code**
   - Scroll to "Promo" section
   - Input field: "Entrer un code promo"
   - Type: `MAS10`
   - Tap "Appliquer" button
   - **Expected behavior**:
     - Button shows loading spinner ⟳ (1-2s)
     - Success message appears: "Réduction appliquée: -8.00€"
     - Discount field updates: "Réduction: -8.00 €" (in green)
     - Input field clears
     - Code remains applied (state persists)

4. **Verify Amount Recalculation**
   - Summary now shows:
     - Sous-total: 80.00 €
     - Réduction: -8.00 € ✅ (10% of 80)
     - Livraison: 20.00 € (or 0 if digital)
     - **Total: 92.00 €**

5. **Complete Checkout**
   - Tap "Payer maintenant"
   - Accept terms (checkbox)
   - Select delivery mode (if merch present):
     - Standard (€20) or Retrait €5
   - Tap "Continuer vers le paiement"
   - Stripe PaymentSheet shows:
     - Amount: **92.00 €** (with discount applied) ✅
   - Complete payment (use test card: 4242 4242 4242 4242)
   - Success: "Paiement confirmé (merch + media)"

6. **Verify Firestore Audit Trail**
   - Go to Firebase Console > Firestore
   - Open `users/{uid}/orders/{storeOrderId}`
   - Verify fields:
     ```json
     {
       "promoCode": "MAS10",
       "promoCentsDiscount": 800,
       "totalCents": 9200,
       "status": "confirmed",
       ...
     }
     ```
     ✅ All promo info correctly saved

### Expected Result

- [x] Code accepted without error
- [x] Discount calculated: 10% × €80 = €8.00
- [x] Final amount: €92.00 (80 - 8 + 20 shipping)
- [x] Payment successful at correct amount
- [x] Firestore order records promo code + discount

### Evidence (Screenshot/Log)

```
PASS: Valid code MAS10 correctly applied -€8.00
Order: store_abc123
PaymentIntent amount: 9200 cents
Firestore promoCode: "MAS10"
promoCentsDiscount: 800
Status: ✅ PASSED
```

---

## Scenario 2: ❌ Minimum Order Not Met

**Objective**: Validate that insufficient cart amount is rejected

### Setup
1. Open app, sign in
2. Add to cart:
   - **Merch item**: €30 (less than MAS10 €50 requirement)
   - **Media item**: €10
   - **Total**: €40

### Steps

1. **Navigate to Checkout**
   - Tap "Panier" → "MASLIVE Checkout"
   - Summary shows:
     - Sous-total: 40.00 €

2. **Try Invalid Code**
   - Scroll to "Promo" section
   - Type: `MAS10` (requires €50 minimum)
   - Tap "Appliquer"
   - **Expected behavior**:
     - Button shows loading ⟳ (1-2s)
     - Error message appears in red: **"Minimum commande: 50.00€"**
     - No discount applied
     - Code not stored in state

3. **Add Items to Reach Minimum**
   - Go back to cart
   - Add €15 more merch
   - New total: €55
   - Return to checkout

4. **Retry Code**
   - Type: `MAS10`
   - Tap "Appliquer"
   - **Expected behavior**:
     - Success message: "Réduction appliquée: -5.50€" ✅
     - Discount field updates
     - Code now accepted

### Expected Result

- [x] Code rejected when total < €50
- [x] Specific error message shown: "Minimum commande"
- [x] After adding items above threshold, code accepted
- [x] Discount correctly calculated on new amount

### Evidence

```
FAIL: MAS10 - Subtotal €40 < €50 minimum
Error: "Minimum commande: 50.00€"
Status: ✅ CORRECTLY REJECTED

PASS: After adding €15 (new total €55)
Discount: 5.50€ (10%)
Status: ✅ NOW ACCEPTED
```

---

## Scenario 3: ❌ Invalid Code

**Objective**: Validate that non-existent codes are rejected with error

### Setup
1. Open app with any cart (€50+)
2. Navigate to checkout

### Steps

1. **Try Fake Code**
   - Scroll to "Promo" section
   - Type: `FAKECODE` (doesn't exist in Firestore)
   - Tap "Appliquer"
   - **Expected behavior**:
     - Button shows loading ⟳
     - Error message appears: **"Code promo invalide"**
     - No discount applied
     - Input field remains visible (doesn't clear)

2. **Try Typo**
   - Clear field
   - Type: `mas10` (lowercase, should auto-uppercase)
   - Tap "Appliquer"
   - **Expected behavior**:
     - Converts to uppercase: `MAS10`
     - Code accepted (if above minimum)
     - OR rejected with appropriate error

3. **Try Empty Code**
   - Clear field (leave empty)
   - Tap "Appliquer"
   - **Expected behavior**:
     - Nothing happens
     - No error/success message
     - Field remains empty

4. **Try Disabled Code** (if available)
   - Go to Firestore, set `codes.MAS10.disabled = true`
   - Type: `MAS10`
   - Tap "Appliquer"
   - **Expected behavior**:
     - Error message: **"Code promo désactivé"**
     - Code rejected

### Expected Result

- [x] Fake code rejected: "Code promo invalide"
- [x] Auto-uppercase works (if implemented)
- [x] Empty code handled gracefully
- [x] Disabled code caught: "Code promo désactivé"
- [x] Error messages clear and actionable

### Evidence

```
FAIL: FAKECODE - Not found in Firestore
Error: "Code promo invalide"
Status: ✅ CORRECTLY REJECTED

FAIL: DISABLED_CODE - disabled flag = true
Error: "Code promo désactivé"
Status: ✅ CORRECTLY REJECTED

IGNORE: Empty input (no action)
Status: ✅ EXPECTED
```

---

## Additional Edge Case Tests (Optional)

### 4. Expired Code

**Setup:**
- Create test code in Firestore with `expiresAt` = past date
- Try to apply in checkout

**Expected**: Error "Code promo expiré"

### 5. Fixed Discount (MEDIA5)

**Setup:**
- Cart €50+
- Apply: `MEDIA5` (€5 fixed, min €20)

**Expected**: 
- Discount: -€5.00 (fixed amount)
- Works for both merch + media

### 6. Capped Discount (WELCOME20)

**Setup:**
- Huge cart €300+
- Apply: `WELCOME20` (20% capped at €20)

**Expected**:
- Calculated: 20% × €300 = €60
- Capped: €20 (max)
- Actual discount: -€20.00

---

## Validation Criteria (All MUST Pass)

| Scenario | Criteria | Status |
|----------|----------|--------|
| **Valid Code** | Correct discount applied | [ ] |
| **Valid Code** | Amount updated in UI | [ ] |
| **Valid Code** | Payment at correct amount | [ ] |
| **Valid Code** | Firestore audit trail | [ ] |
| **Min Order** | Rejected if < minimum | [ ] |
| **Min Order** | Specific error message | [ ] |
| **Min Order** | Accepted when threshold met | [ ] |
| **Invalid Code** | Rejected gracefully | [ ] |
| **Invalid Code** | Clear error shown | [ ] |
| **Invalid Code** | No side effects | [ ] |

---

## Bug Report Template

If any test fails, document:

```
SCENARIO: [Number + Name]
STEPS TO REPRODUCE:
  1. ...
  2. ...
EXPECTED:
  - ...
ACTUAL:
  - ...
LOGS:
  firebase functions:logs read validatePromoCode --limit 10
  [paste logs]
SCREENSHOT:
  [attach]
STATUS: FAILED ❌
```

---

## Sign-off

**Tested By**: _______________
**Date**: _______________
**All Scenarios Passed**: [ ] YES   [ ] NO

**Comments**:
_______________________________________________________________________________

---

**Next Step**: If all tests pass, system is ready for production release! 🚀
