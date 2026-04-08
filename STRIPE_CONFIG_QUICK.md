# ⚡ Configuration Stripe - Méthode Secret Manager

## 🚀 Secret principal

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
```

La CLI Firebase te demandera de coller ta Secret key Stripe depuis https://dashboard.stripe.com/apikeys

## 🔁 Secret webhook (optionnel mais recommandé)

```bash
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

À renseigner avec le Signing secret `whsec_...` du webhook Stripe.

## 📋 Ou utilise le script interactif

```bash
bash /workspaces/MASLIVE/deploy_functions_stripe.sh
```

## 🔄 Redéployer après configuration

```bash
firebase deploy --only functions
```

## 📱 Clé publique pour le checkout natif

Le panier merch et le panier mixte utilisent Stripe PaymentSheet sur mobile natif. Fournis la clé publique au build :

```bash
cd /workspaces/MASLIVE/app
flutter build apk --release --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_KEY_HERE
```

## 📚 Références

- **Récupérer ta Secret key** : https://dashboard.stripe.com/apikeys
- **Récupérer ton webhook signing secret** : https://dashboard.stripe.com/webhooks
- **Mode test** : Clés `sk_test_...` et `pk_test_...`
- **Mode production** : Clés `sk_live_...` et `pk_live_...`

## ⚠️ Nota bene

- Ne jamais committer une clé Stripe dans le code
- Le code actuel lit `STRIPE_SECRET_KEY` via Firebase Secret Manager, avec fallback `process.env.STRIPE_SECRET_KEY` pour le local
- Le web checkout externe fonctionne sans `STRIPE_PUBLISHABLE_KEY`, mais PaymentSheet merch/mixte reste un flow natif
