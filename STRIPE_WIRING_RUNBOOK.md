# Runbook — Câblage Stripe paiement boutique

Suite à l'implémentation P0/P1/P2. Ce document couvre les étapes **opérationnelles**
(secrets, dashboard Stripe, activation) qui ne sont pas dans le code, plus la
référence des nouvelles fonctions.

---

## 1. Secrets Firebase (P0 — bloquant)

```bash
# Clé secrète Stripe (sk_test_... en test, sk_live_... en prod)
firebase functions:secrets:set STRIPE_SECRET_KEY

# Secret de signature du webhook (whsec_...) — voir étape 2
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET

# Redéployer les functions pour prendre en compte les secrets
firebase deploy --only functions
```

## 2. Endpoint webhook (P0 — bloquant)

Dashboard Stripe → **Developers → Webhooks → Add endpoint** :

- **URL** : `https://us-east1-maslive.cloudfunctions.net/stripeWebhook`
- **Événements à cocher** :
  - `checkout.session.completed`
  - `payment_intent.succeeded`
  - `payment_intent.payment_failed`   ← nouveau (P1)
  - `charge.refunded`                 ← nouveau (P1)
  - `charge.dispute.created`          ← nouveau (P1)
  - `account.updated`
  - `customer.subscription.updated`, `customer.subscription.deleted`
  - `invoice.paid`, `invoice.payment_failed`

Récupérer le **Signing secret** (`whsec_...`) → le poser dans `STRIPE_WEBHOOK_SECRET`
(étape 1). Sans ce secret, `stripeWebhook` répond 500 et **aucune commande n'est
finalisée**.

## 3. Clé publiable côté app (P0 — mobile)

Ajouter dans le `.env` racine (voir `.env.example`) :

```
STRIPE_PUBLISHABLE_KEY=pk_live_xxx       # ou pk_test_xxx
STRIPE_APPLE_MERCHANT_ID=merchant.com.maslive   # optionnel (Apple Pay)
```

Les scripts `deploy_firebase.sh` et `commit_push_build_deploy.sh` injectent
automatiquement `--dart-define=STRIPE_PUBLISHABLE_KEY=...` au build. Sans elle,
`main.dart` saute l'init Stripe et **la PaymentSheet native ne s'ouvre pas**.
Le **web** n'en a pas besoin (paiement via Stripe Checkout en redirection).

---

## 4. Activation du reversement vendeurs — Connect (P1)

Le reversement est **désactivé par défaut** (sécurité). Pour l'activer, créer le
document Firestore `config/stripe_connect` :

```jsonc
{
  "autoTransferEnabled": true,   // false = aucun virement auto (défaut)
  "feeBps": 1000,                 // commission plateforme en basis points (1000 = 10%)
  "minPayoutCents": 0             // montant net minimum pour déclencher un virement
}
```

Modèle appliqué : **separate transfers**. À chaque commande payée,
`settleStorexOrderTransfers` verse à chaque vendeur (`item.sellerId`) sa part
merch (prix × quantité) **moins la commission**. Le frais de port reste à la
plateforme. La part **photo** (media marketplace) suit son propre `payout_ledger`
(inchangé). **Bloom Art** est hors périmètre (panier + offres séparés).

Pré-requis par vendeur : un compte Connect actif dans `businesses/{sellerId}` avec
`stripe.accountId` et `stripe.chargesEnabled === true` (via
`createBusinessConnectOnboardingLink`). Un vendeur non éligible est **ignoré**
(sa part reste sur la plateforme, statut `pending_account` dans `orders/{id}.payouts`)
— le virement pourra être refait plus tard.

Traçabilité : `orders/{orderId}.payouts.{sellerId}` = `{ status, transferId,
grossCents, feeCents, netCents }`. Statuts : `transferred`, `pending_account`,
`skipped`, `failed`, `reversed`.

---

## 5. Remboursements & litiges (P1)

- **Remboursement** : callable admin `refundStorexOrder({ orderId, amountCents })`
  (`amountCents` omis/0 = total). Crée le refund Stripe ; le webhook `charge.refunded`
  met la commande en `refunded` / `partially_refunded`, **réincrémente le stock**
  (remboursement total) et **annule les virements Connect** déjà versés
  (`transfers.createReversal`).
- **Échec de paiement** : `payment_intent.payment_failed` passe la commande en
  `payment_failed` (aucun stock n'avait été décrémenté).
- **Litige / chargeback** : `charge.dispute.created` passe la commande en `disputed`.

---

## 6. Vérification finale

```bash
# Diagnostic de configuration (admin) — doit renvoyer ready: true
# callable: getStripeReadinessReport

# Test webhooks en local
stripe listen --forward-to localhost:5001/maslive/us-east1/stripeWebhook
```

Cartes de test : `4242 4242 4242 4242` (succès), `4000 0025 0000 3155` (3DS),
`4000 0000 0000 9995` (refus → payment_failed).

---

## 7. Ce qui reste manuel / hors code

- Poser les 2 secrets et enregistrer l'endpoint webhook (étapes 1–2).
- Créer/activer `config/stripe_connect` quand le reversement auto est validé.
- Fournir `STRIPE_PUBLISHABLE_KEY` (+ `STRIPE_APPLE_MERCHANT_ID`) dans l'environnement
  de build mobile ; pour iOS, configurer le Merchant ID Apple Pay dans Xcode.
