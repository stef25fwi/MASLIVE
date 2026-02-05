# 🔐 Guide : Régénération des credentials Firebase

## Pourquoi régénérer ?
Les anciennes credentials ont été **brièvement exposées dans l'historique Git** (maintenant nettoyé). Par précaution de sécurité, il est recommandé de les révoquer et d'en générer de nouvelles.

## Étapes dans Firebase Console

### 1. Accéder aux comptes de service
1. Aller sur https://console.firebase.google.com/project/maslive/settings/serviceaccounts/adminsdk
2. Ou : Console Firebase → **⚙️ Paramètres du projet** → **Comptes de service**

### 2. Révoquer l'ancienne clé (optionnel mais recommandé)
1. Dans la section **Clés de compte de service existantes**, trouver la clé actuelle
2. Cliquer sur **︙** (trois points) → **Révoquer la clé**
3. Confirmer la révocation

**⚠️ Attention** : Après révocation, l'ancien fichier JSON ne fonctionnera plus !

### 3. Générer une nouvelle clé
1. Cliquer sur **Générer une nouvelle clé privée**
2. Confirmer dans le dialogue → un fichier JSON sera téléchargé
3. Le fichier s'appellera quelque chose comme :
   ```
   maslive-firebase-adminsdk-XXXXX-YYYYYYY.json
   ```

### 4. Remplacer le fichier local
```bash
# Dans votre terminal local (PAS dans l'historique Git !)
cd /workspaces/MASLIVE

# Option A : Renommer pour garder le même nom
mv ~/Downloads/maslive-firebase-adminsdk-*.json ./maslive-firebase-adminsdk-fbsvc-c6d30fab6a.json

# Option B : Utiliser le nouveau nom et mettre à jour la variable d'environnement
export GOOGLE_APPLICATION_CREDENTIALS="/workspaces/MASLIVE/maslive-firebase-adminsdk-NOUVEAU-NOM.json"
```

### 5. Tester les nouvelles credentials
```bash
# Vérifier que l'inspection fonctionne
export GOOGLE_APPLICATION_CREDENTIALS="/workspaces/MASLIVE/maslive-firebase-adminsdk-fbsvc-c6d30fab6a.json"
node inspect_shop_products.js
```

Si vous voyez la liste des **5 produits**, tout fonctionne ! ✅

### 6. Vérifier .gitignore
Le pattern est déjà en place :
```gitignore
*firebase-adminsdk*.json
```

**Aucun** fichier de credentials ne sera jamais commité grâce à ce pattern.

---

## Scripts affectés
Ces scripts utilisent `GOOGLE_APPLICATION_CREDENTIALS` :
- ✅ `inspect_shop_products.js` - Inspection produits
- ✅ `migrate_shop_products.js` - Migration champs normalisés
- ✅ `seed_demo_products.js` - Seed données démo
- ✅ `cleanup_test_products.js` - Nettoyage produits test

Tous continueront de fonctionner avec les nouvelles credentials.

---

## Sécurité : Bonnes pratiques
- ✅ **Jamais** commiter les fichiers `*-adminsdk-*.json`
- ✅ Révoquer immédiatement si exposition suspecte
- ✅ Utiliser des variables d'environnement locales
- ✅ En production : utiliser des **service accounts** avec rôles limités
- ✅ Activer l'authentification à deux facteurs sur compte Firebase

---

## Commandes rapides

```bash
# Exporter la variable (à faire dans chaque session terminal)
export GOOGLE_APPLICATION_CREDENTIALS="/workspaces/MASLIVE/maslive-firebase-adminsdk-fbsvc-c6d30fab6a.json"

# Ou ajouter dans ~/.bashrc pour persistance :
echo 'export GOOGLE_APPLICATION_CREDENTIALS="/workspaces/MASLIVE/maslive-firebase-adminsdk-fbsvc-c6d30fab6a.json"' >> ~/.bashrc
source ~/.bashrc

# Tester rapidement
node inspect_shop_products.js && echo "✅ Credentials OK"
```

---

**Status actuel** : System fonctionnel avec credentials actuelles. Régénération recommandée mais **non bloquante**.
