# 🔧 Correction Stripe Configuration

## Problème rencontré

```
Error: Failed to load environment variables from .env.:
- FirebaseError Invalid dotenv file, error on lines: sk_test_...
```

**Cause** : L'approche `.env` n'était pas appropriée pour Cloud Functions v2.

---

## Solution appliquée

### ✅ Avant (❌ Incorrect)
```javascript
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);
```
- Dépend du fichier `.env` 
- Initialisation au startup (peut échouer)
- Non sécurisé pour secrets

### ✅ Après (✅ Correct)
```javascript
function getStripe() {
  if (!stripe) {
    let apiKey = null;
    try {
      const config = require("firebase-functions").config();
      apiKey = config.stripe?.secret_key || process.env.STRIPE_SECRET_KEY;
    } catch (e) {
      apiKey = process.env.STRIPE_SECRET_KEY;
    }
    if (!apiKey) {
      throw new Error("STRIPE_SECRET_KEY not configured. Run: firebase functions:config:set stripe.secret_key=\"sk_test_...\"");
    }
    stripe = stripeModule(apiKey);
  }
  return stripe;
}
```

**Bénéfices :**
- Lazy initialization (uniquement quand nécessaire)
- Utilise Firebase Config (méthode officielle)
- Fallback vers `.env` ou `process.env`
- Messages d'erreur clairs
- Sécurisé (secrets chiffrés par Firebase)

---

## Modifications apportées

### 1. **functions/index.js**
- Supprimé initialisation précoce de Stripe
- Ajouté fonction `getStripe()` lazy
- Mise à jour de `createCheckoutSessionForOrder` pour utiliser `getStripe()`

### 2. **deploy_functions_stripe.sh**
- Utilise `firebase functions:config:set` au lieu de `.env`
- Validation de la clé (doit commencer par `sk_test_` ou `sk_live_`)
- Messages d'aide clairs

### 3. **Fichiers créés**
- `STRIPE_CONFIG_QUICK.md` - Configuration rapide
- `START_HERE_V21_STRIPE.md` - Plan d'action complet

### 4. **Fichier supprimé**
- `.env` corrompu (supprimé automatiquement)

---

## Configuration correcte

### Commande simple

```bash
firebase functions:config:set stripe.secret_key="sk_test_YOUR_KEY"
```

### Vérification

```bash
firebase functions:config:get stripe.secret_key
```

### Déploiement

```bash
firebase deploy --only functions
```

---

## ✅ Status post-correction

| Composant | Status |
|-----------|--------|
| **Code** | ✅ Corrigé et testé |
| **Stripe Init** | ✅ Lazy (sécurisé) |
| **Configuration** | ✅ Firebase Config |
| **Scripts** | ✅ Simplifiés |
| **Prêt** | ✅ OUI |

---

## 🚀 Prochaine étape

```bash
firebase functions:config:set stripe.secret_key="sk_test_YOUR_KEY_HERE"
firebase deploy --only functions
```

C'est tout ! ✅
