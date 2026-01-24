# Configuration Webhook Stripe

## 📋 Vue d'ensemble

Le webhook Stripe permet de recevoir des notifications en temps réel lorsque des événements se produisent (paiement réussi, compte Connect mis à jour, etc.).

## 🔧 Étapes de configuration

### 1. Déployer la fonction webhook

La fonction `stripeWebhook` est déjà dans `/functions/index.js`. Déploie-la :

```bash
cd /workspaces/MASLIVE
cd functions && npm ci && cd ..
firebase deploy --only functions:stripeWebhook
```

### 2. Obtenir l'URL du webhook

Après déploiement, l'URL sera :
```
https://us-east1-maslive.cloudfunctions.net/stripeWebhook
```

### 3. Configurer le webhook dans Stripe Dashboard

1. Va sur https://dashboard.stripe.com/webhooks
2. Clique sur **"Add endpoint"**
3. **Endpoint URL** : `https://us-east1-maslive.cloudfunctions.net/stripeWebhook`
4. **Description** : "MASLIVE Firebase webhook"
5. **Events to send** (sélectionne ces événements) :
   - ✅ `checkout.session.completed` - Commande payée (Media Shop)
   - ✅ `payment_intent.succeeded` - Paiement réussi
   - ✅ `account.updated` - Statut du compte Connect changé
   - ✅ `account.application.authorized` (optionnel)
   - ✅ `account.application.deauthorized` (optionnel)
6. Clique **"Add endpoint"**

### 4. Copier le signing secret

Une fois le webhook créé, Stripe affiche un **Signing secret** (commence par `whsec_...`).

**IMPORTANT** : Copie cette clé, elle sera utilisée pour vérifier la signature des webhooks (sécurité).

### 5. Configurer le signing secret dans Firebase

**Option A : Via Firebase CLI** (recommandé)
```bash
firebase functions:config:set stripe.webhook_secret="whsec_..."
firebase deploy --only functions
```

**Option B : Variable d'environnement**
Ajoute dans `.env` de `/functions` (si tu utilises `.env`) :
```
STRIPE_WEBHOOK_SECRET=whsec_...
```

### 6. Vérifier le déploiement

Redéploie les functions après avoir configuré le secret :
```bash
firebase deploy --only functions:stripeWebhook
```

## 🧪 Tester le webhook

### Test depuis Stripe Dashboard

1. Va sur https://dashboard.stripe.com/webhooks
2. Clique sur ton webhook endpoint
3. Onglet **"Send test webhook"**
4. Sélectionne `checkout.session.completed` ou `account.updated`
5. Clique **"Send test event"**
6. Vérifie les logs Firebase :
   ```bash
   firebase functions:log --only stripeWebhook
   ```

### Test en local (optionnel)

1. Installe Stripe CLI : https://stripe.com/docs/stripe-cli
2. Lance le forward local :
   ```bash
   stripe listen --forward-to http://localhost:5001/maslive/us-east1/stripeWebhook
   ```
3. Déclenche un événement de test :
   ```bash
   stripe trigger checkout.session.completed
   ```

## 📊 Événements gérés

| Événement | Description | Action |
|-----------|-------------|--------|
| `checkout.session.completed` | Session Checkout terminée (paiement réussi) | Met à jour commande → `status: 'paid'`, crée documents `purchases/{photoId}` |
| `payment_intent.succeeded` | Confirmation paiement réussi | Log (traitement principal dans checkout.session.completed) |
| `account.updated` | Statut du compte Connect Express changé | Met à jour `businesses/{uid}/stripe` (chargesEnabled, payoutsEnabled, etc.) |

## 🔐 Sécurité

- ✅ Vérification de signature webhook (via `stripe.webhooks.constructEvent`)
- ✅ Secret stocké dans Firebase config (pas dans le code)
- ✅ Seules les requêtes POST sont acceptées
- ✅ Validation des métadonnées (orderId, userId, uid)

## 🐛 Debugging

### Voir les logs du webhook

```bash
firebase functions:log --only stripeWebhook
```

### Erreurs fréquentes

**"Webhook signature verification failed"**
→ Le `webhook_secret` n'est pas configuré ou incorrect. Vérifie avec :
```bash
firebase functions:config:get
```

**"Order not found"**
→ Le `metadata.orderId` ou `metadata.userId` manque dans la session Checkout. Vérifie que `createCheckoutSessionForOrder` ajoute bien ces métadonnées.

**"Business profile not found"**
→ Le compte Stripe Connect n'a pas de `metadata.uid`. Assure-toi que `createBusinessConnectOnboardingLink` ajoute `metadata: { uid }` lors de la création du compte.

## 📝 Notes importantes

1. **Test vs Production** : Configure un webhook différent pour chaque environnement (test/prod) avec les bonnes clés `webhook_secret`.

2. **Idempotence** : Les webhooks peuvent être envoyés plusieurs fois (retry). Les opérations Firestore doivent être idempotentes (ex: `set(..., { merge: true })`).

3. **Timeout** : Le webhook a 30s pour répondre. Si le traitement est long, réponds `200 OK` rapidement et traite en arrière-plan.

4. **Monitoring** : Stripe Dashboard > Webhooks > ton endpoint affiche l'historique des événements et leur statut de traitement.

## ✅ Checklist finale

- [ ] Fonction `stripeWebhook` déployée
- [ ] Webhook créé dans Stripe Dashboard
- [ ] Signing secret configuré dans Firebase (`stripe.webhook_secret`)
- [ ] Events sélectionnés : `checkout.session.completed`, `account.updated`, `payment_intent.succeeded`
- [ ] Test envoyé depuis Stripe Dashboard → succès (code 200)
- [ ] Logs Firebase confirment la réception et le traitement
- [ ] Firestore mis à jour après événement test
