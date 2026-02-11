# Correctifs de sécurité Stripe — MASLIVE Functions

**Date**: 2026-02-11  
**Fichier**: `functions/index.js`

## Résumé des vulnérabilités corrigées

### 🔴 Critique

#### 1. `createCheckoutSession` (HTTP) : Auth obligatoire + Redirect allowlist stricte
**Problème initial** :
- Endpoint HTTP accessible sans authentification
- `isAllowedRedirectUrl()` acceptait toute URL `https://...` (pas de whitelist)
- Un attaquant connaissant un `orderId` pouvait récupérer le `session_id` via un redirect malveillant

**Correctif appliqué** :
- ✅ Auth obligatoire via `getUidFromAuthorizationHeader(req)` (ligne ~1613)
- ✅ Ownership check : vérifie que `order.userId === uid` avant de créer la session (ligne ~1641)
- ✅ `isAllowedRedirectUrl()` implémente une whitelist stricte :
  - Production : `maslive.web.app`, `maslive.firebaseapp.com`
  - Dev : `localhost`, `127.0.0.1`
- ✅ `idempotencyKey: order_${orderId}` pour éviter les doubles sessions (ligne ~1680)

**Impact** : Risque de vol de session / fraude éliminé.

---

#### 2. Discount négatif dans `createCheckoutSessionForOrder`
**Problème initial** :
- La fonction ajoutait un line item avec `unit_amount: -discountCents`
- Stripe Checkout refuse les montants négatifs → crash au runtime

**Correctif appliqué** :
- ✅ `discountCents` forcé à `0` (pas de politique de discount côté serveur)
- ✅ Aucun line item négatif ajouté aux `lineItems`
- ✅ Recalcul des prix depuis `/photos/{photoId}` (source de vérité) au lieu de `users/{uid}/orders`

**Impact** : Crash Stripe éliminé + prix sécurisés (non modifiables par le client).

---

### 🟠 Élevé

#### 3. `createMediaShopCheckout` : Idempotence Stripe
**Problème initial** :
- Pas d'`idempotencyKey` dans `stripeClient.checkout.sessions.create()`
- Double-clic / appels concurrents → risque de sessions multiples

**Correctif appliqué** :
- ✅ `idempotencyKey: mediaShop_${uid}_${orderId}` ajouté (ligne ~1967)
- Stripe garantit qu'une seule session est créée même en cas d'appels concurrents

**Impact** : Risque de double paiement éliminé.

---

#### 4. Vidage du panier avant confirmation de paiement
**Problème initial** :
- `createMediaShopCheckout` supprimait `users/{uid}/cart` immédiatement après création de session
- Si l'utilisateur annule/échoue → perte du panier (mauvaise UX)

**Correctif appliqué** :
- ✅ Suppression du `batch.delete(cartRef)` dans `createMediaShopCheckout`
- ✅ Le panier est maintenant vidé **uniquement après paiement confirmé** dans `handleCheckoutSessionCompleted()` (webhook)

**Impact** : Meilleure UX + panier préservé en cas d'échec/annulation.

---

### 🟡 Moyen

#### 5. Images Stripe : URL publiques HTTPS requises
**Problème initial** :
- `images: [item.thumbPath]` dans `product_data`
- `thumbPath` peut être un chemin Storage (`events/...`) non public → Stripe refuse l'image

**Correctif appliqué** :
- ✅ Privilégier `thumbUrl` (URL publique HTTPS) dans les line items
- ✅ Valider que l'URL commence par `https://` avant de l'envoyer à Stripe
- ✅ Omettre l'image si aucune URL publique n'est disponible

**Impact** : Fiabilité des images dans Checkout Stripe améliorée.

---

#### 6. Statuts de commande (documenté)
**Observation** :
- `checkout.session.completed` met `status: "paid"`
- `payment_intent.succeeded` met `status: "confirmed"`
- Peut créer des cas limites si l'UI/analytics attend un statut unique

**Décision** :
- ⚠️ Pas de modification pour l'instant (comportement webhook standard)
- Recommandation : utiliser `status: "paid"` comme statut principal après paiement
- `confirmed` peut être utilisé comme statut secondaire pour les paiements nécessitant une validation manuelle

---

## Checklist de conformité

- ✅ Toutes les fonctions critiques authentifient l'utilisateur
- ✅ Recalcul des prix côté serveur (pas de confiance en données client)
- ✅ Redirect URLs strictement contrôlées (allowlist)
- ✅ IdempotencyKey Stripe sur toutes les créations de session
- ✅ Ownership checks (utilisateur ne peut agir que sur ses propres ressources)
- ✅ Panier vidé uniquement après confirmation de paiement (webhook)
- ✅ Images Stripe validées (URL publiques HTTPS uniquement)

---

## Prochaines étapes recommandées

1. **Firestore Rules** : resserrer `shops/{shopId}/orders` (actuellement `allow create: if true;`)
2. **Monitoring** : logger les tentatives d'accès non autorisées (auth failures)
3. **Tests** : valider le flow complet Checkout + webhook en environnement staging
4. **Documentation** : mettre à jour la doc API pour refléter les nouvelles exigences d'auth

---

**Statut actuel** : ✅ Tous les correctifs critiques et élevés déployés.
