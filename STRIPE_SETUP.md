# Configuration Stripe pour Cloud Functions

## 1. Installation des dépendances

```bash
cd functions
npm install
```

## 2. Configuration de la clé Stripe

### Option A : Variable d'environnement Firebase (Production)

```bash
firebase functions:config:set stripe.secret_key="sk_live_YOUR_KEY"
```

Puis modifie `index.js` ligne 18 :
```javascript
const stripe = require("stripe")(functions.config().stripe.secret_key);
```

### Option B : Variable d'environnement système (Local/Dev)

1. Crée un fichier `.env` dans `/functions` :
```bash
cp .env.example .env
```

2. Édite `.env` et ajoute ta clé :
```
STRIPE_SECRET_KEY=sk_test_YOUR_KEY
```

3. Installe `dotenv` :
```bash
npm install dotenv
```

4. Charge les variables au début de `index.js` :
```javascript
require('dotenv').config();
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);
```

## 3. Webhook Stripe (Optionnel mais recommandé)

Pour marquer automatiquement les commandes comme "paid" :

1. Dans Stripe Dashboard → Webhooks, ajoute un endpoint :
   - URL : `https://us-east1-YOUR_PROJECT.cloudfunctions.net/stripeWebhook`
   - Événements : `checkout.session.completed`

2. Ajoute cette fonction dans `index.js` :

```javascript
exports.stripeWebhook = onRequest(
  { region: "us-east1" },
  async (req, res) => {
    const sig = req.headers["stripe-signature"];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    let event;
    try {
      event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    } catch (err) {
      console.error("Webhook signature verification failed:", err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    if (event.type === "checkout.session.completed") {
      const session = event.data.object;
      const { orderId, uid } = session.metadata;

      // Marque la commande comme payée
      await db.collection("users").doc(uid).collection("orders").doc(orderId).update({
        status: "paid",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        stripePaymentIntentId: session.payment_intent,
      });

      // Écrit les purchases individuelles
      const orderSnap = await db.collection("users").doc(uid).collection("orders").doc(orderId).get();
      const items = orderSnap.data()?.items || [];

      const batch = db.batch();
      for (const item of items) {
        const purchaseRef = db.collection("users").doc(uid).collection("purchases").doc(item.photoId);
        batch.set(purchaseRef, {
          photoId: item.photoId,
          orderId,
          purchasedAt: admin.firestore.FieldValue.serverTimestamp(),
          priceCents: item.priceCents,
          eventName: item.eventName,
          groupName: item.groupName,
          photographerName: item.photographerName,
          thumbPath: item.thumbPath,
          fullPath: item.fullPath,
        });
      }
      await batch.commit();
    }

    res.json({ received: true });
  }
);
```

## 4. Déploiement

```bash
cd /workspaces/MASLIVE
firebase deploy --only functions
```

## 5. Test

Dans l'app Flutter, après avoir créé une commande, clique sur "Créer checkout Stripe". Tu seras redirigé vers la page de paiement Stripe.

**Carte de test Stripe :**
- Numéro : `4242 4242 4242 4242`
- Date : N'importe quelle date future
- CVC : N'importe quel 3 chiffres
