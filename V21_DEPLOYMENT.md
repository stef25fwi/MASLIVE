# 📦 MASLIVE V2.1 - Boutique Photos avec Monétisation

## 🎯 Nouvelles fonctionnalités V2.1

✅ **Recherche textuelle** - Filtrer par événement, groupe, photographe, pays  
✅ **Système de packs discount** - 3 photos (-10%), 5 photos (-20%), 10 photos (-30%)  
✅ **Sélection rapide** - Long press sur les photos pour sélectionner  
✅ **Precache d'images** - Chargement fluide lors du scroll  
✅ **Intégration Stripe** - Paiement en ligne sécurisé  
✅ **Panier amélioré** - Affichage du discount et total final  

---

## 🚀 Déploiement rapide

### Étape 1 : Activer V2.1

Le fichier V2.1 est prêt dans `app/lib/pages/media_shop_page_v21.dart`.

**Option 1 - Script automatique (recommandé) :**
```bash
bash /workspaces/MASLIVE/activate_shop_v21.sh
```

**Option 2 - Commande manuelle :**
```bash
cd /workspaces/MASLIVE/app/lib/pages
cp media_shop_page.dart media_shop_page_v20_backup.dart
cp media_shop_page_v21.dart media_shop_page.dart
```

### Étape 2 : Build et déployer

```bash
cd /workspaces/MASLIVE
# Build web
flutter build web --release

# Déploie tout
firebase deploy --only hosting,functions
```

Ou utilise la **task VS Code** : `MASLIVE: Déployer Hosting (1 clic)`

### Étape 3 : Configurer Stripe

```bash
bash /workspaces/MASLIVE/deploy_functions_stripe.sh
```

Le script demandera ta clé Stripe et déploiera automatiquement.

---

## 🔑 Configuration Stripe

### Récupérer ta clé Stripe

1. Va sur [dashboard.stripe.com/apikeys](https://dashboard.stripe.com/apikeys)
2. Copie la clé **Secret key** en mode test
3. Colle-la quand le script te la demande

### Mode test vs Production

- **Développement** : Utilise `sk_test_...`
- **Production** : Utilise `sk_live_...`

---

## 🧪 Test complet

### Carte de test Stripe
```
Numéro   : 4242 4242 4242 4242
Date     : N'importe quelle date future (ex: 12/25)
CVC      : N'importe quel 3 chiffres (ex: 123)
```

### Étapes de test

1. **Ouvre l'app** : https://maslive.web.app
2. **Boutique Photos** → Ajoute 3+ photos au panier
3. **Clique** sur le panier en haut à droite
4. **Crée une commande** (stockée en Firestore)
5. **Lance le checkout Stripe** (redirection vers le paiement)
6. **Utilise la carte de test**
7. **Confirmation** : La commande passe en "paid" et la photo est ajoutée aux achats

---

## 📂 Fichiers modifiés/créés

| Fichier | Description |
|---------|-------------|
| `app/lib/pages/media_shop_page_v21.dart` | Nouvelle implémentation V2.1 |
| `app/lib/pages/media_shop_page.dart` | Sera remplacé par V2.1 |
| `functions/index.js` | Callable Stripe `createCheckoutSessionForOrder` |
| `functions/package.json` | Stripe SDK ajouté |
| `activate_shop_v21.sh` | Script d'activation V2.1 |
| `deploy_functions_stripe.sh` | Script de déploiement Stripe |
| `QUICK_STRIPE_DEPLOY.md` | Guide rapide |
| `STRIPE_SETUP.md` | Documentation complète |

---

## ⚙️ Architecture Firestore

```
/users/{uid}/
├── /orders/{orderId}/
│   ├── status: "pending" | "paid" | "failed"
│   ├── totalCents: number
│   ├── discountCents: number
│   ├── discountRule: "PACK_3" | "PACK_5" | "PACK_10" | ""
│   ├── items: [
│   │   {
│   │     photoId, eventName, groupName,
│   │     photographerName, priceCents, ...
│   │   }
│   │ ]
│   ├── stripeSessionId: string
│   ├── stripeSessionUrl: string
│   └── createdAt: timestamp
│
└── /purchases/{photoId}/
    ├── photoId: string
    ├── orderId: string
    ├── purchasedAt: timestamp
    └── priceCents: number
```

---

## 🐛 Troubleshooting

### Erreur : "STRIPE_SECRET_KEY not set"
- Réexécute le script de déploiement : `bash /workspaces/MASLIVE/deploy_functions_stripe.sh`
- Ou configure manuellement : `firebase functions:config:set stripe.secret_key="sk_test_..."`

### Paiement refused
- Utilise la carte de test officielle
- Assure-toi qu'au moins 3 photos sont dans le panier
- Vérifier les logs Firebase : `firebase functions:log`

### Images ne se chargent pas
- Vérifier que Firebase Storage paths sont corrects
- Vérifier les CORS settings dans Storage

---

## 📞 Support

Pour plus d'aide :
- Voir [STRIPE_SETUP.md](STRIPE_SETUP.md) pour configuration complète
- Voir [QUICK_STRIPE_DEPLOY.md](QUICK_STRIPE_DEPLOY.md) pour déploiement rapide
- Voir [functions/index.js](functions/index.js) pour détails technique du callable
- Dashboard Firebase : https://console.firebase.google.com

---

**V2.1 est prête à être déployée ! 🚀**
