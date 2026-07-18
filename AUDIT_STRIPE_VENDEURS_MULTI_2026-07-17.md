# Audit Stripe — Associations / Photographes / Bloom Art / Abonnement restaurateur (tables libres)

_Date : 2026-07-17 · Branche : `claude/stripe-connectors-verify-66okc6`_

Complément à `AUDIT_STRIPE_PAIEMENT_BOUTIQUE_2026-07-12.md` (checkout Storex/merch,
déjà audité et non repris ici). Ce document couvre les 4 autres types de
"vendeurs" de la plateforme, avec le focus : qui est payé, comment, et ce qui
manque pour un reversement réel.

---

## 1. Associations — pas de flux dédié

Il n'existe **pas de rôle/collection "association"** séparé. Une association est
une simple valeur de dropdown "forme juridique" sur le flux `business` générique.

- `app/lib/pages/business_signup_page.dart:64` — `'Association loi 1901'` fait
  partie de `_legalForms` (SARL, SAS, auto-entrepreneur, etc.).
- `app/lib/pages/business_signup_page.dart:153-177` — à l'inscription, écrit
  `businesses/{uid}.legalForm` tel quel ; aucun champ `role`/`accountType` distinct.
- **0 occurrence** de `association` dans `functions/index.js` (grep insensible
  à la casse) : le champ `legalForm` n'est jamais lu côté serveur.

**Conséquence** : même flux Connect que n'importe quel business
(`createBusinessConnectOnboardingLink`, `functions/index.js:3372-3468`) :
- `business_type: "company"` **hardcodé** (ligne 3425), alors que Stripe propose
  `business_type: "non_profit"`, plus adapté fiscalement/légalement à une
  association loi 1901. Non utilisé.
- Gate d'onboarding : `business.status === "approved"` requis (ligne 3398-3403),
  `ownerUid` vérifié (ligne 3394-3396), pays supporté requis (ligne 3412-3418).
- Reversement : identique au merch (`transfers.create`, ligne 4489, réversion
  possible sur remboursement, ligne 4745) — commission `feeBps` configurable.

**Manque** :
- [ ] Pas de `business_type: "non_profit"` pour les associations déclarées.
- [ ] Pas de gestion fiscale spécifique (reçus fiscaux, TVA) — `legalForm` est
      purement déclaratif, jamais exploité.

---

## 2. Photographes (media marketplace)

`functions/src/media-marketplace-stripe.js`, exposé `functions/index.js:806-822`.

### a) Vente de photos/packs — `createMediaMarketplaceCheckout` (ligne 841-1025)
- ✅ Verrou anti-race-condition (`checkoutLockedUntil`, ligne 869-897).
- ✅ Recalcul serveur des prix + vérif `isPublished`/`moderationStatus === approved`
  (`assertValidPhotoForSale` ligne 170-184, `assertValidPackForSale` ligne 186-206).
- ✅ Idempotence Stripe (`media_marketplace_checkout_${uid}_${orderId}`, ligne 989).
- ✅ Webhook `handleMarketplaceCheckoutSessionCompleted` → `fulfillMarketplaceOrder`
  (ligne 475-586) crée `media_entitlements` + `payout_ledger`, transactionnel.

### b) Abonnement photographe — `createPhotographerSubscriptionCheckoutSession` (ligne 1027-1164)
- ✅ Vérifie `photographer.ownerUid`, plan actif, anti-doublon d'abonnement
  (transaction Firestore, ligne 1078-1104).
- ✅ Price IDs stockés dans Firestore (`photographer_plans/{id}.stripePriceMonthlyId/AnnualId`),
  pas dans `.env` (documenté dans `functions/.env.example`).
- ✅ Webhook complet : `customer.subscription.updated/deleted`,
  `invoice.paid/payment_failed` (ligne 1182-1257).

### ⚠️ Onboarding Stripe Connect photographe : **inexistant**
0 résultat pour `transfer_data`/`application_fee_amount`/`on_behalf_of`/
`transfers.create` dans tout le module. Aucune fonction équivalente à
`createPhotographerConnectOnboardingLink`. Un profil `photographers/{id}` est
créé `status: "approved"` automatiquement à la publication (`functions/index.js:5140-5147`),
sans jamais passer par Connect — rien ne bloque la vente faute de compte payable.

### ⚠️ Reversement réel : **`payout_ledger` est un registre mort**
- `payout_ledger/{orderId_assetId}` écrit `grossAmount`/`platformFee`/`stripeFee`/
  `netAmount`/`payoutStatus: "available"` à chaque vente (ligne 532-555, 786-809).
- Ce ledger est **seulement lu** pour agréger des compteurs d'affichage
  (`recalculatePhotographerCounters`, `media-marketplace-media.js:206-243`).
- **Aucun `stripe.transfers.create` n'est jamais appelé** pour un photographe :
  100 % du montant payé reste sur le compte plateforme.
- `PayoutLedgerModel` (Dart) a un champ `payoutBatchId` suggérant un mécanisme
  de "batch payout" prévu mais jamais implémenté côté backend.

### Commission plateforme
`computeOrderBreakdown` (ligne 259-278) calcule `platformFee` depuis le
`commissionRate` du plan actif du photographe — un calcul comptable **sans
effet réel sur l'argent** (pas de séparation Stripe).

**Résumé** : checkout + subscription solides ; le vendeur n'est **jamais payé**.

---

## 3. Créateurs Bloom Art

`functions/src/bloom-art.js`, exposé `functions/index.js:827-831`.

### Vérification vendeur — solide côté serveur
`getVerifiedSellerProfile` (ligne 129-172), appelé par `createBloomArtItem` (ligne 179) :
- ✅ `profileType === "artisan_art"` requis (ligne 144-149) — un profil
  `je_me_lance` ne peut pas créer d'item.
- ✅ `sellerStatus === "active"` et `businessVerificationStatus === "verified"`
  (ligne 151-156).
- ✅ SIRET `^\d{14}$` obligatoire (ligne 158-163), lu côté serveur (pas de
  confiance dans une déclaration client).

### Flux offre → checkout
- ✅ Auto-accept si offre ≥ 90 % du `referencePrice` privé (non lisible côté
  client, sous-collection `private`) — anti-triche sur le prix (ligne 26,
  101-108, 193, 227-232).
- ✅ `acceptBloomArtOffer`/`declineBloomArtOffer` transactionnels, anti double-vente
  (ligne 350-365).
- ✅ `createBloomArtCheckout` (ligne 411-554) : idempotence
  (`bloom_art_checkout_${uid}_${orderId}`, ligne 527), réutilisation de session
  existante, rollback `orderStatus: failed` sur erreur Stripe.
- ✅ Webhook `handleBloomArtCheckoutCompleted` (ligne 556-617) : décline
  automatiquement toutes les autres offres pendantes sur l'item vendu.

### ⚠️ Reversement à l'artiste : **inexistant, mais prévu côté modèle Dart (dette visible)**
0 résultat pour `transfer_data`/`application_fee_amount`/`on_behalf_of`/
`transfers.create` dans `bloom-art.js`. La Checkout Session ne contient aucun
`payment_intent_data` avec destination Connect.

Le modèle `BloomArtSellerProfile` (Dart) contient pourtant :
- `stripeAccountLinked: bool` — **jamais lu/écrit** par le backend (grep = 0).
- `payoutStatus: String` (default `'pending'`) — **jamais mis à jour** par le backend.
- `canSell` getter **ne dépend pas** de `stripeAccountLinked` — cohérent avec le
  fait que le backend ne vérifie pas non plus de compte Connect avant de vendre.

Vestige d'une conception Connect jamais implémentée pour Bloom Art.

### ⚠️ Commission plateforme : **absente**
Aucun calcul de commission — le prix Stripe Checkout = `offer.proposedPrice`
intégral (ligne 494, 508). 100 % du montant va à la plateforme.

**Résumé** : c'est le flux le plus incomplet des quatre côté "argent au
vendeur" — même le bookkeeping (`payout_ledger`) qui existe pour les
photographes n'existe pas ici.

---

## 4. Abonnement restaurateur "tables libres" (live tables)

`functions/src/restaurant-live-tables.js`, exposé `functions/index.js:817-822`.
**Le flux le plus complet des quatre.**

### Plans
`LIVE_TABLE_ALLOWED_PLAN_CODES = {food_pro_live, food_premium, restaurant_live_plus}`
(ligne 13-17). Price IDs résolus par convention `STRIPE_PRICE_${PLAN}_${MONTHLY|ANNUAL}`
(ligne 44-58), cohérents avec `functions/.env.example:25-30`. Vérifiés par
`getStripeReadinessReport` (`functions/index.js:3653-3659`).

### `createRestaurantLiveTableSubscriptionCheckoutSession` (ligne 379-494)
- ✅ Vérifie `ownerUid`, statut business approuvé.
- ✅ Anti-doublon d'abonnement actif (ligne 419-427).
- ✅ Checkout `mode: subscription`, idempotence
  (`business_live_table_subscription_${uid}_${planCode}_${billingInterval}`).
- ✅ Metadata `kind: "business_live_table_subscription"` propagée sur la session
  **et** `subscription_data.metadata` — garantit que le webhook retrouve le
  `kind` même sur des événements ultérieurs sans `checkout.session.completed`.
- ✅ État `checkout_pending` écrit immédiatement (affichage optimiste UI).

### Déblocage de la fonctionnalité sur la fiche POI
- `setRestaurantLiveTableStatus` (ligne 269-377) : autorisé si `isAdmin` OU
  (`isOwner` ET (`isUserPremium` OU `isBusinessSubscribed`)) — **double voie**
  de déblocage (abonnement premium utilisateur OU abonnement business).
- Mirroir côté client : `RestaurantSubscriptionGuard.hasActiveLiveTableFeature`
  (`app/lib/features/restaurant_live_tables/services/restaurant_subscription_guard.dart:10-25`).

### Webhooks — tous câblés
`checkout.session.completed`, `customer.subscription.updated/deleted`,
`invoice.paid/payment_failed` (`functions/index.js:668-754` pour le sync central,
plus les 5 handlers). `customer.subscription.deleted` force `status: canceled`
+ `features.liveTableStatusEnabled: false` ; `invoice.payment_failed` force
`status: past_due` + désactivation de la fonctionnalité.

### Coexistence avec le Connect merch — propre
`liveTableSubscription.*` et `stripe.accountId` (Connect) vivent sur le même
doc `businesses/{uid}` mais sur des champs disjoints, sans dépendance croisée
(confirmé par grep). Normal : c'est un abonnement business→plateforme, pas une
vente à reverser — l'absence de `transfer_data` ici n'est **pas un manque**.

**Résumé** : rien à corriger en urgence sur ce flux.

---

## Synthèse comparative

| Flux | Onboarding Connect vendeur | Transfert réel au vendeur | Commission définie | Statut compte requis avant vente |
|---|---|---|---|---|
| Merch/Storex (audit 07-12) | Oui | **Oui** (+ réversion) | Oui (`feeBps`) | `chargesEnabled` vérifié |
| Associations | Identique au merch (`business_type` mal typé) | Oui (même mécanisme) | Oui (`feeBps`) | Identique au merch |
| Photographes | **Non** | **Non — jamais** | Oui (calculée, jamais appliquée) | Aucun |
| Bloom Art | **Non** | **Non — jamais** | **Non — absente** | Non (SIRET vérifié, pas de Connect) |
| Live tables (abonnement) | N/A (pas une vente à reverser) | N/A | N/A (abonnement plateforme) | N/A |

## Priorisation

| Priorité | Élément | Impact |
|---|---|---|
| 🔴 P0 | Câbler le reversement réel photographes (Connect onboarding + `transfers.create` consommant `payout_ledger`) | Dette financière réelle envers les photographes, pas juste config |
| 🔴 P0 | Câbler le reversement réel Bloom Art (Connect onboarding + commission + transfert) | Idem, artistes jamais payés |
| 🟠 P1 | `business_type: "non_profit"` pour les associations lors de l'onboarding Connect | Conformité fiscale/légale |
| 🟡 P2 | Nettoyer/implémenter `stripeAccountLinked`/`payoutStatus` sur `BloomArtSellerProfile` (vestige non câblé) | Cohérence modèle ↔ backend |

> Live tables (section 4) est solide et ne nécessite pas d'action immédiate.
> Storex/merch et associations ont un cycle de reversement complet. Les deux
> points bloquants réels sont photographes et Bloom Art : la plateforme
> encaisse 100 % sans jamais reverser aux vendeurs.
