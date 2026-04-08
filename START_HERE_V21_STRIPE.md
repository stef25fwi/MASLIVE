# 🎯 Plan d'action complet V2.1 + Stripe

## Étape 1️⃣ : Activer V2.1 (App Flutter)

```bash
bash /workspaces/MASLIVE/activate_shop_v21.sh
```

**Résultat :**
- V2.0 sauvegardé en `media_shop_page_v20_backup.dart`
- V2.1 activé en `media_shop_page.dart`

---

## Étape 2️⃣ : Configurer Stripe (Cloud Functions)

### Option A : Configuration rapide (recommandée)

**D'abord, obtiens ta clé :**
1. Va sur https://dashboard.stripe.com/apikeys
2. Copie la clé **Secret key** (commence par `sk_test_`)

**Puis configure :**
```bash
cd /workspaces/MASLIVE
firebase functions:secrets:set STRIPE_SECRET_KEY
```

Exemple :
```bash
# La CLI te demandera de coller la valeur de STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_SECRET_KEY
```

### Option B : Script interactif (si tu préfères)

```bash
bash /workspaces/MASLIVE/deploy_functions_stripe.sh
```

Le script demandera ta clé et la configurera automatiquement.

---

## Étape 3️⃣ : Configurer le webhook (recommandé)

```bash
cd /workspaces/MASLIVE
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

Colle le Signing secret `whsec_...` depuis Stripe Dashboard → Webhooks.

---

## Étape 4️⃣ : Déployer tout (App + Functions)

```bash
cd /workspaces/MASLIVE && firebase deploy --only hosting,functions
```

Ou utilise la **task VS Code** : `MASLIVE: Déployer Hosting (1 clic)`

---

## Étape 5️⃣ : Test complet

1. **Ouvre l'app** : https://maslive.web.app
2. **Boutique Photos** → Ajoute **3+ photos**
3. **Vérifies** le discount `-10%` s'affiche
4. **Clique** "Créer commande"
5. **Clique** "Créer checkout Stripe"
6. **Utilise la carte test** :
   ```
   Numéro : 4242 4242 4242 4242
   Date   : 12/25 (ou date future)
   CVC    : 123
   ```
7. **Complète le paiement**

**Résultat attendu :**
- Tu reviens sur `success?orderId=...`
- La commande passe en "paid" dans Firestore
- Les photos sont marquées comme "Achetées"

**Attention :**
- Ce flow web concerne les checkouts Stripe externes
- Le panier merch principal et le panier mixte utilisent PaymentSheet et doivent être testés sur mobile natif

---

## ✅ Checklist post-déploiement

- [ ] V2.1 activé (no compilation errors)
- [ ] Clé Stripe configurée
- [ ] Cloud Functions déployées
- [ ] App accessible sur https://maslive.web.app
- [ ] Recherche textuelle fonctionne
- [ ] Filtres en cascade fonctionnent
- [ ] Long-press sur photos fonctionne
- [ ] Discount affiche correctement (3/5/10 photos)
- [ ] Panier fonctionne
- [ ] Paiement Stripe fonctionne
- [ ] Commande marquée "paid"

---

## 🆘 Dépannage

### Erreur : "STRIPE_SECRET_KEY not configured"

**Solution :**
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase deploy --only functions
```

### Erreur : "Invalid dotenv file"

**Solution :**
```bash
rm -f /workspaces/MASLIVE/functions/.env
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

### Paiement ne fonctionne pas

**Vérifier :**
1. Secret Stripe présent dans Firebase Secret Manager
2. Logs : `firebase functions:log`
3. Firestore : Vérifier que les commandes sont créées

### Commande reste en "pending"

**Cause possible :** Webhook Stripe n'est pas configuré (optionnel mais recommandé)  
**Solution :** Voir `STRIPE_SETUP.md` section "Webhook Stripe"

---

## 📚 Références

- Clé Stripe : https://dashboard.stripe.com/apikeys
- Dashboard Firebase : https://console.firebase.google.com
- Logs Functions : `firebase functions:log`
- Documentation complète : Voir `V21_DEPLOYMENT.md`

---

## 🚀 Commandes les plus importantes

```bash
# Activer V2.1
bash /workspaces/MASLIVE/activate_shop_v21.sh

# Configurer Stripe (remplace ta clé)
firebase functions:secrets:set STRIPE_SECRET_KEY

# Configurer le webhook (recommandé)
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET

# Déployer
firebase deploy --only hosting,functions

# Voir les logs
firebase functions:log
```

---

**Prêt ? Commence par l'Étape 1️⃣ !**
