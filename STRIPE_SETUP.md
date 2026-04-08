# Configuration Stripe pour Cloud Functions

## 1. Installation des dépendances

```bash
cd functions
npm install
```

## 2. Configuration de la clé Stripe

### Option A : Firebase Secret Manager (Production)

```bash
cd /workspaces/MASLIVE
firebase functions:secrets:set STRIPE_SECRET_KEY
```

Aucune modification manuelle de `functions/index.js` n'est nécessaire.
Le code actuel lit déjà :

```javascript
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
```

### Option B : Variable d'environnement système (Local/Dev)

Pour les tests locaux ou émulateurs, tu peux fournir la variable d'environnement dans ton shell :

```bash
export STRIPE_SECRET_KEY=sk_test_YOUR_KEY
```

Le code utilisera `process.env.STRIPE_SECRET_KEY` en fallback.

## 3. Webhook Stripe (Optionnel mais recommandé)

Le endpoint `stripeWebhook` existe déjà dans le dépôt. Il te reste à :

1. Dans Stripe Dashboard → Webhooks, ajoute un endpoint :
   - URL : `https://us-east1-maslive.cloudfunctions.net/stripeWebhook`
   - Événements : `checkout.session.completed`, `payment_intent.succeeded`, `account.updated`

2. Configure le secret signé côté Firebase :

```bash
cd /workspaces/MASLIVE
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

## 4. Déploiement

```bash
cd /workspaces/MASLIVE
firebase deploy --only functions
```

## 5. Test

### Flows web compatibles

- Media marketplace
- Premium / abonnements
- Live tables

Ces flows renvoient une `checkoutUrl` Stripe externe compatible web.

### Flows mobiles natifs

- Merch checkout
- Mixed cart checkout

Ces flows utilisent Stripe PaymentSheet. Pour les tester sur mobile natif, fournis la clé publique au build :

```bash
cd /workspaces/MASLIVE/app
flutter build apk --release --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_KEY
```

**Carte de test Stripe :**
- Numéro : `4242 4242 4242 4242`
- Date : N'importe quelle date future
- CVC : N'importe quel 3 chiffres
