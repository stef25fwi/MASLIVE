# 📋 Commandes à copier/coller (dans l'ordre)

## 1️⃣ Activer V2.1
```bash
bash /workspaces/MASLIVE/activate_shop_v21.sh
```

## 2️⃣ Obtenir ta clé Stripe
Ouvre https://dashboard.stripe.com/apikeys et copie la clé Secret (sk_test_...)

## 3️⃣ Configurer Stripe dans Firebase
Remplace `sk_test_YOUR_KEY_HERE` par ta vraie clé :
```bash
firebase functions:config:set stripe.secret_key="sk_test_YOUR_KEY_HERE"
```

Exemple complet :
```bash
firebase functions:config:set stripe.secret_key="sk_test_YOUR_ACTUAL_KEY_FROM_STRIPE_DASHBOARD"
```

## 4️⃣ Vérifier la configuration
```bash
firebase functions:config:get stripe.secret_key
```

## 5️⃣ Déployer
```bash
cd /workspaces/MASLIVE && firebase deploy --only hosting,functions
```

---

## 🧪 Après déploiement - Test

1. Ouvre https://maslive.web.app
2. Va à "Boutique Photos"
3. Ajoute 3+ photos au panier
4. Crée une commande
5. Lance Stripe checkout
6. Utilise : `4242 4242 4242 4242` (date: 12/25, CVC: 123)

---

**C'est tout ! 🚀**
