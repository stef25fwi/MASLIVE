# 🚀 Déploiement avec Stripe - Étapes rapides

## 1. Lance le script de déploiement
```bash
bash /workspaces/MASLIVE/deploy_functions_stripe.sh
```

## 2. Entre ta clé Stripe
Le script demandera ta clé Secret Key depuis le [Stripe Dashboard](https://dashboard.stripe.com/apikeys).

**Clés de test :**
- Mode test : `sk_test_...`
- Mode production : `sk_live_...`

## 3. Attends la fin du déploiement
Les Cloud Functions seront déployées automatiquement.

---

## 📝 Configuration manuelle (si besoin)

Si tu veux configurer Stripe manuellement après :

```bash
firebase functions:config:set stripe.secret_key="sk_test_YOUR_KEY"
firebase deploy --only functions
```

---

## 🧪 Test du paiement

1. **Build l'app Flutter V2.1 :**
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
   - Ajoute quelques photos au panier (3+ pour avoir une réduction)
   - Clique sur "Créer commande"
   - Clique sur "Créer checkout Stripe"
   - Utilise la carte test : `4242 4242 4242 4242`

---

## 📚 Références

- [Guide d'installation Stripe](STRIPE_SETUP.md)
- [Dashboard Stripe](https://dashboard.stripe.com)
- [Documentation Cloud Functions](functions/index.js)
