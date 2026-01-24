# ⚡ Configuration Stripe - Méthode Firebase Config

## 🚀 Commande unique (recommandée)

```bash
firebase functions:config:set stripe.secret_key="sk_test_YOUR_KEY_HERE"
```

Remplace `sk_test_YOUR_KEY_HERE` par ta vraie clé depuis https://dashboard.stripe.com/apikeys

## 📋 Ou utilise le script interactif

```bash
bash /workspaces/MASLIVE/deploy_functions_stripe.sh
```

Le script demandera ta clé et l'ajouter automatiquement à Firebase.

## ✅ Vérifier la configuration

```bash
firebase functions:config:get stripe.secret_key
```

Tu devrais voir : `sk_test_...` ou `sk_live_...`

## 🔄 Redéployer après configuration

```bash
firebase deploy --only functions
```

## 📚 Références

- **Récupérer ta clé** : https://dashboard.stripe.com/apikeys
- **Mode test** : Clés commençant par `sk_test_`
- **Mode production** : Clés commençant par `sk_live_`

## ⚠️ Nota bene

- Ne jamais committer ta clé dans le code
- Firebase Config est le moyen sécurisé de stocker les secrets
- La clé est chiffrée et stockée dans Firebase
