# 📋 Commandes à copier/coller (dans l'ordre)

## 1️⃣ Activer V2.1
```bash
bash /workspaces/MASLIVE/activate_shop_v21.sh
```

## 2️⃣ Configurer le secret Stripe principal
```bash
cd /workspaces/MASLIVE
firebase functions:secrets:set STRIPE_SECRET_KEY
```

## 3️⃣ Optionnel : configurer le secret webhook
```bash
cd /workspaces/MASLIVE
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

## 4️⃣ Déployer les functions
```bash
cd /workspaces/MASLIVE
firebase deploy --only functions
```

## 5️⃣ Déployer le hosting
```bash
cd /workspaces/MASLIVE
firebase deploy --only hosting
```

## 6️⃣ Build mobile natif si tu testes merch ou mixed checkout
```bash
cd /workspaces/MASLIVE/app
flutter build apk --release --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_KEY_HERE
```

---

## 🧪 Après déploiement - Test

1. Ouvre https://maslive.web.app
2. Va à "Boutique Photos"
3. Ajoute 3+ photos au panier
4. Crée une commande
5. Lance Stripe checkout
6. Utilise : `4242 4242 4242 4242` (date: 12/25, CVC: 123)

Note : le checkout merch principal et le mixed checkout restent des flows mobiles natifs.

---

**C'est tout ! 🚀**
