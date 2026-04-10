# 🚀 Stripe prêt à l'emploi - chemin court

## 1. Setup guidé Functions + env runtime

```bash
bash /workspaces/MASLIVE/deploy_functions_stripe.sh
```

Le script configure :
- `STRIPE_SECRET_KEY` dans Firebase Secret Manager
- `STRIPE_WEBHOOK_SECRET` dans Firebase Secret Manager
- `functions/.env` pour les price IDs runtime non secrets
- `.env` racine pour les price IDs premium utilisés au build web

## 2. Variables réellement requises

### Secrets Firebase

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY --project maslive
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project maslive
```

### Runtime Functions non secret

Dans `functions/.env` :

```bash
STRIPE_PREMIUM_MONTHLY_PRICE_ID=price_...
STRIPE_PREMIUM_YEARLY_PRICE_ID=price_...
STRIPE_PRICE_FOOD_PRO_LIVE_MONTHLY=price_...
STRIPE_PRICE_FOOD_PRO_LIVE_ANNUAL=price_...
STRIPE_PRICE_FOOD_PREMIUM_MONTHLY=price_...
STRIPE_PRICE_FOOD_PREMIUM_ANNUAL=price_...
STRIPE_PRICE_RESTAURANT_LIVE_PLUS_MONTHLY=price_...
STRIPE_PRICE_RESTAURANT_LIVE_PLUS_ANNUAL=price_...
```

### Build web Flutter

Dans `.env` racine :

```bash
MAPBOX_ACCESS_TOKEN=pk.eyJ...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_PREMIUM_MONTHLY_PRICE_ID=price_...
STRIPE_PREMIUM_YEARLY_PRICE_ID=price_...
```

### Build mobile natif

Le PaymentSheet mobile nécessite `STRIPE_PUBLISHABLE_KEY`, stockable aussi dans `.env` racine :

```bash
flutter build apk --release --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
```

## 3. Flux Stripe couverts dans le code actuel

- `Storex web` : Stripe Checkout externe
- `Storex mobile` : PaymentSheet natif
- `Panier mixte web` : Stripe Checkout externe
- `Panier mixte mobile` : PaymentSheet natif
- `Media marketplace` : Stripe Checkout externe
- `Premium web` : Stripe Checkout externe
- `Restaurant live tables` : Stripe Checkout externe
- `Stripe Connect business` : onboarding Express + refresh statut

Note importante :
- les prix `photographer_plans` ne sont pas lus depuis l’env, mais depuis Firestore :
   `photographer_plans/{planId}.stripePriceMonthlyId` et `stripePriceAnnualId`

## 4. Vérification admin immédiate

Dans l’app admin :

1. Ouvre `Dashboard admin`
2. Clique `Test Stripe`
3. Lis le rapport de préparation

Le rapport contrôle :
- secrets Stripe
- env premium
- env live tables
- plans photographes sans price IDs
- businesses approuvés avec pays non supporté pour Connect

## 5. Déploiement web + backend

Scripts mis à jour pour injecter automatiquement les price IDs premium s’ils sont présents dans `.env` :

```bash
bash /workspaces/MASLIVE/build_deploy_now.sh
bash /workspaces/MASLIVE/deploy_firebase.sh
bash /workspaces/MASLIVE/deploy_production.sh
```

## 6. Test Stripe rapide

Carte Stripe test :

```text
4242 4242 4242 4242
12/25
123
```

Checklist minimale :
- Storex web : checkout ouvert puis commande payée
- Premium web : checkout ouvert sans message de config manquante
- Live tables : ouverture checkout selon le plan choisi
- Business account : onboarding Stripe Connect accessible

## Références

- [Guide d'installation Stripe](STRIPE_SETUP.md)
- [Guide webhook Stripe](STRIPE_WEBHOOK_SETUP.md)
- [Code backend Stripe](functions/index.js)
