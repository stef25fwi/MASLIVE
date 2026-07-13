# Audit Stripe — Paiement boutiques (Storex / merch)

_Date : 2026-07-12 · Branche : `claude/stripe-payment-audit-j378j6`_

Audit de l'implémentation réelle du paiement Stripe dans les boutiques, et
checklist de ce qu'il reste à câbler pour un flux de paiement complet et sûr.

---

## 1. Ce qui EST déjà implémenté ✅

### Backend (`functions/index.js`)
- **`createStorexPaymentIntent`** (mobile natif) → crée la commande + un
  `PaymentIntent` (`automatic_payment_methods`) et renvoie `clientSecret` pour la
  PaymentSheet. Idempotence sur `orderId`.
- **`createStorexCheckoutSession`** (web) → crée la commande + une Stripe
  Checkout Session (mode `payment`, redirection). Idempotence
  `storex_checkout_${orderId}`.
- **`createMixedCartPaymentIntent` / `createMixedCartCheckoutSession`** pour
  panier mixte merch + media.
- **Re-calcul serveur des prix** depuis la collection `products`
  (`createStorexOrderDraftFromMerchCart`) — les montants du panier client ne sont
  jamais utilisés. Vérifie `isActive`, `moderationStatus === approved`, shipping
  en whitelist `{0, 500, 2000}`. **Sécurité correcte.**
- **`stripeWebhook`** : vérification de signature (`constructEvent`), rejet des
  non-POST, **idempotence** via `_stripe_webhook_events` (`claimStripeWebhookEvent`).
  Événements traités : `checkout.session.completed`, `payment_intent.succeeded`,
  `customer.subscription.updated/deleted`, `invoice.paid`,
  `invoice.payment_failed`, `account.updated`.
- **`finalizeStorexOrderPayment`** : transaction Firestore qui passe la commande
  en `paid`, écrit `/orders/{id}` + `/users/{uid}/orders/{id}`, crée
  `purchases/{orderId}`, **décrémente le stock** (`decrementStorexStockForRootOrder`)
  et **vide le panier** (`clearStorexCartItems`). Anti-double-traitement.
- **Stripe Connect (onboarding)** : `createBusinessConnectOnboardingLink` (comptes
  Express), `refreshBusinessConnectStatus`, sync via `account.updated`.
- **`getStripeReadinessReport`** (admin) : diagnostic de config par flux.
- **`validatePromoCode`**.

### Client (Flutter)
- `main.dart` → `_initializeStripe()` : `Stripe.publishableKey` via
  `--dart-define=STRIPE_PUBLISHABLE_KEY` (natif uniquement, web ignoré).
- `storex_checkout_stripe.dart` : pages Delivery + Payment, PaymentSheet natif /
  redirection web.
- `CheckoutGateway`, `UnifiedCheckoutService`, `CartCheckoutService` : routage
  merch / media / mixte centralisé.

---

## 2. Checklist — ce qu'il MANQUE pour câbler Stripe 🔧

### A. Configuration & secrets (bloquant déploiement)
- [ ] **`STRIPE_SECRET_KEY`** défini dans Firebase Secret Manager
      (`firebase functions:secrets:set STRIPE_SECRET_KEY`) — test **et** prod.
- [ ] **`STRIPE_WEBHOOK_SECRET`** défini (sinon `stripeWebhook` renvoie 500 et
      **aucune commande n'est finalisée**).
- [ ] **Endpoint webhook enregistré** dans le dashboard Stripe →
      `https://us-east1-maslive.cloudfunctions.net/stripeWebhook`, avec au minimum
      les events : `checkout.session.completed`, `payment_intent.succeeded`,
      `payment_intent.payment_failed`, `charge.refunded`, `account.updated`,
      `customer.subscription.*`, `invoice.*`.
- [ ] **`STRIPE_PUBLISHABLE_KEY` dans les builds** — ⚠️ **absent de TOUS les scripts
      de build** (`build_and_deploy.sh`, `deploy_firebase.sh`,
      `commit_push_build_deploy.sh`… ne passent que Mapbox/premium). Sans le
      `--dart-define=STRIPE_PUBLISHABLE_KEY=pk_...`, `_initializeStripe()` fait
      `return` et **la PaymentSheet mobile ne s'initialise jamais**.
- [ ] Price IDs abonnements dans `functions/.env` (`STRIPE_PREMIUM_*`,
      `STRIPE_PRICE_FOOD_*`) — nécessaires aux flux subscription, pas au merch.

### B. Reversement vendeurs — Stripe Connect (fonctionnel majeur)
- [ ] **Aucun `transfer_data` / `application_fee_amount` / `on_behalf_of`** dans
      `createStorexPaymentIntent` ni `createStorexCheckoutSession` (grep = 0
      résultat). L'onboarding Connect existe, mais **l'argent des ventes merch va
      à 100 % sur le compte plateforme** ; les vendeurs (`item.sellerId`) ne sont
      jamais payés automatiquement. À décider et câbler :
  - [ ] soit **destination charges** (`payment_intent_data.transfer_data.destination`
        = compte Connect du vendeur) — impose 1 seul vendeur par commande, ou une
        commande par vendeur ;
  - [ ] soit **separate transfers** post-paiement (un `transfer` par `sellerId`) ;
  - [ ] définir la **commission plateforme** (`application_fee_amount`).
- [ ] Bloquer le checkout si le vendeur d'un article n'a pas
      `stripe.chargesEnabled === true`.

### C. Robustesse du cycle de vie de la commande
- [ ] **`payment_intent.payment_failed`** non traité → une commande refusée reste
      `pending` indéfiniment (pas de retour user, pas de libération de stock).
- [ ] **Remboursements / litiges** : pas de handler `charge.refunded` /
      `charge.dispute.created`, pas de fonction de refund (`stripe.refunds.create`).
      Le statut commande ne peut pas repasser en `refunded`.
- [ ] **Finalisation mobile dépend uniquement du webhook** : après
      `presentPaymentSheet()`, le client vide le panier et navigue vers l'écran
      succès de façon optimiste, alors que le passage en `paid` (stock, purchases)
      n'a lieu qu'au webhook. Si le webhook est mal configuré → succès affiché mais
      commande jamais finalisée. Prévoir une vérif serveur du PaymentIntent avant
      l'écran succès, ou un écran « en cours de confirmation ».
- [ ] **Reçu Stripe** : `receipt_email` non renseigné sur le PaymentIntent
      (seul `customer_email` est mis sur la Checkout Session web).

### D. Moyens de paiement & UX
- [ ] **Apple Pay / Google Pay** non configurés dans la PaymentSheet
      (`applePay` / `googlePay` + `merchantIdentifier`) alors qu'un onglet
      « wallet » existe côté UI (`maslive_ultra_premium_checkout_page.dart`).
- [ ] Gestion explicite du **retour/annulation web** (l'utilisateur revient de
      Stripe sans payer → panier conservé, message clair).

### E. Tests & validation
- [ ] Test E2E en **mode test** (cartes `4242…`, 3DS `4000 0025 0000 3155`).
- [ ] `stripe listen --forward-to` vers l'émulateur pour valider les handlers
      webhook localement.
- [ ] Vérifier `getStripeReadinessReport` → `ready: true` avant mise en prod.

---

## 3. Priorisation

| Priorité | Élément | Impact |
|---|---|---|
| 🔴 P0 | Secrets `STRIPE_SECRET_KEY` + `STRIPE_WEBHOOK_SECRET` + endpoint webhook | Sans ça, 0 commande finalisée |
| 🔴 P0 | `STRIPE_PUBLISHABLE_KEY` dans les builds mobiles | PaymentSheet natif inopérante |
| 🟠 P1 | Connect `transfer_data`/commission pour merch | Vendeurs non payés |
| 🟠 P1 | `payment_intent.payment_failed` + remboursements | Commandes fantômes, pas de SAV |
| 🟡 P2 | Vérif serveur avant écran succès mobile | Faux positifs de paiement |
| 🟡 P2 | Apple/Google Pay, `receipt_email` | Conversion & UX |

> Les briques de sécurité les plus délicates (re-calcul serveur des prix,
> signature + idempotence webhook, transaction de finalisation) sont **déjà
> solides**. Le travail restant est surtout : **configuration/secrets**,
> **reversement Connect** et **gestion des échecs/remboursements**.
