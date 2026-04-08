# 🚀 Déploiement avec Stripe - Étapes rapides

## 1. Lance le script de déploiement
```bash
bash /workspaces/MASLIVE/deploy_functions_stripe.sh
```

## 2. Configure les secrets Stripe
Le script ouvre la saisie sécurisée de :
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET` en option

## 3. Attends la fin du déploiement
Les Cloud Functions Stripe seront redéployées automatiquement.

---

## 📝 Configuration manuelle (si besoin)

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase deploy --only functions
```

Webhook recommandé :

```bash
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
firebase deploy --only functions
```

---

## 🧪 Test du paiement

### Flow web validé dans ce dépôt

1. **Build l'app Flutter web :**
```bash
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release
```

2. **Déploie sur Firebase Hosting :**
```bash
cd /workspaces/MASLIVE
firebase deploy --only hosting
```

3. **Dans l'app :**
   - Ajoute quelques photos au panier
   - Lance le checkout Stripe externe
   - Utilise la carte test : `4242 4242 4242 4242`

### Point d'attention

- Les flows media, premium et live tables utilisent une `checkoutUrl` Stripe externe et sont compatibles web
- Le panier merch principal et le panier mixte utilisent PaymentSheet et sont à considérer comme flows mobiles natifs à ce stade

---

## 📚 Références

- [Guide d'installation Stripe](STRIPE_SETUP.md)
- [Dashboard Stripe](https://dashboard.stripe.com)
- [Documentation Cloud Functions](functions/index.js)
