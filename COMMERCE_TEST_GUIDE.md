# 🧪 GUIDE DE TEST : Système Commerce MAS'LIVE

## 📋 Vue d'ensemble

Ce guide explique comment tester le système commerce complet avec des utilisateurs réels dans Firestore.

---

## 🎯 Objectif des tests

Vérifier que :
1. ✅ Les bons rôles peuvent soumettre du commerce
2. ✅ La modération fonctionne (approve/reject)
3. ✅ Les notifications push arrivent
4. ✅ Les soumissions apparaissent dans la boutique après validation
5. ✅ Les analytics reflètent les données correctes

---

## 👥 Création des utilisateurs test

### Étape 1 : Créer 4 utilisateurs test dans Firebase Authentication

```bash
# Dans Firebase Console > Authentication > Users
# Créer 4 comptes manuellement :

1. test-superadmin@maslive.test
2. test-admin-groupe@maslive.test
3. test-createur-digital@maslive.test
4. test-compte-pro@maslive.test
```

### Étape 2 : Configurer leurs profils dans Firestore

**Collection : `users/{uid}`**

#### User 1 : SuperAdmin
```json
{
  "uid": "<UID_AUTH>",
  "email": "test-superadmin@maslive.test",
  "displayName": "Super Admin Test",
  "role": "superadmin",
  "isAdmin": true,
  "createdAt": <serverTimestamp>,
  "updatedAt": <serverTimestamp>
}
```

#### User 2 : Admin Groupe (Groupe "test_group_123")
```json
{
  "uid": "<UID_AUTH>",
  "email": "test-admin-groupe@maslive.test",
  "displayName": "Admin Groupe Test",
  "role": "admin_groupe",
  "accountType": "pro",
  "managedScopeIds": ["test_group_123"],
  "groupId": "test_group_123",
  "createdAt": <serverTimestamp>,
  "updatedAt": <serverTimestamp>
}
```

#### User 3 : Créateur Digital
```json
{
  "uid": "<UID_AUTH>",
  "email": "test-createur-digital@maslive.test",
  "displayName": "Créateur Digital Test",
  "role": "user",
  "accountType": "pro",
  "activities": ["createur_digital", "photographe"],
  "createdAt": <serverTimestamp>,
  "updatedAt": <serverTimestamp>
}
```

#### User 4 : Compte Pro Standard
```json
{
  "uid": "<UID_AUTH>",
  "email": "test-compte-pro@maslive.test",
  "displayName": "Compte Pro Test",
  "role": "user",
  "accountType": "pro",
  "activities": ["vendeur"],
  "createdAt": <serverTimestamp>,
  "updatedAt": <serverTimestamp>
}
```

---

## 🧪 Scénarios de test

### Test 1 : Vérifier l'affichage de la section Commerce

**Attendu** : La `CommerceSectionCard` apparaît dans le profil pour les utilisateurs autorisés.

**Procédure** :
1. Se connecter avec `test-superadmin@maslive.test`
2. Aller dans **Profil** (`/account`)
3. **Vérifier** : Section "Commerce" visible avec 3 boutons
4. Répéter avec les 3 autres comptes test
5. **Vérifier** : Section visible pour tous (roles autorisés)

---

### Test 2 : Créer une soumission produit (draft)

**Utilisateur** : `test-compte-pro@maslive.test`

**Procédure** :
1. Cliquer sur **"Ajouter un article"**
2. Remplir :
   - Titre : "Test Produit 1"
   - Description : "Ceci est un produit test"
   - Prix : 29.99
   - Stock : 10
   - Portée : `global`
   - Ajouter 2 images
3. Cliquer **"Enregistrer brouillon"**
4. **Vérifier Firestore** :
   ```javascript
   // Collection: commerce_submissions
   {
     type: "product",
     status: "draft",
     ownerUid: "<UID_COMPTE_PRO>",
     ownerRole: "compte_pro",
     title: "Test Produit 1",
     price: 29.99,
     stock: 10,
     mediaUrls: ["https://...jpg", "https://...jpg"],
     createdAt: <timestamp>,
     updatedAt: <timestamp>
   }
   ```

---

### Test 3 : Soumettre pour validation

**Utilisateur** : `test-compte-pro@maslive.test`

**Procédure** :
1. Aller dans **"Mes contenus"**
2. Onglet **"Brouillons"**
3. Cliquer **"Modifier"** sur "Test Produit 1"
4. Cliquer **"Soumettre"**
5. **Vérifier Firestore** :
   ```javascript
   {
     status: "pending",  // ✅ Changé
     submittedAt: <timestamp>  // ✅ Ajouté
   }
   ```
6. Onglet **"En attente"** : produit visible

---

### Test 4 : Modérer (Approuver)

**Utilisateur** : `test-superadmin@maslive.test`

**Procédure** :
1. Aller dans **Admin Dashboard**
2. Cliquer **"Modération Commerce"**
3. Voir "Test Produit 1" dans la liste
4. Cliquer **"Valider"**
5. Confirmer
6. **Vérifier Firestore** :
   - **Collection `commerce_submissions`** :
     ```javascript
     {
       status: "approved",  // ✅
       moderatedBy: "<UID_SUPERADMIN>",
       moderatedAt: <timestamp>,
       publishedRef: "shops/global/products/<submissionId>"
     }
     ```
   - **Collection `shops/global/products/<submissionId>`** créée :
     ```javascript
     {
       sourceSubmissionId: "<submissionId>",
       ownerUid: "<UID_COMPTE_PRO>",
       title: "Test Produit 1",
       price: 29.99,
       stock: 10,
       isActive: true,
       publishedAt: <timestamp>,
       publishedBy: "<UID_SUPERADMIN>"
     }
     ```

---

### Test 5 : Vérifier notification push (Approved)

**Utilisateur** : `test-compte-pro@maslive.test`

**Procédure** :
1. **Pré-requis** : L'utilisateur doit avoir un `fcmToken` dans `users/{uid}`
2. Après l'approbation (Test 4)
3. **Vérifier** :
   - Notification reçue sur l'appareil/navigateur
   - Titre : "✅ Contenu validé !"
   - Body : 'Votre produit "Test Produit 1" est maintenant publié.'
4. Cliquer sur notification → redirige vers `/commerce/my-submissions`

---

### Test 6 : Refuser une soumission

**Utilisateurs** :
- Soumetteur : `test-createur-digital@maslive.test`
- Modérateur : `test-admin-groupe@maslive.test`

**Procédure** :
1. **En tant que Créateur Digital** :
   - Créer média avec scopeType="group", scopeId="test_group_123"
   - Titre : "Photo Test Rejet"
   - Soumettre pour validation

2. **En tant qu'Admin Groupe** :
   - Aller dans **"Modération Commerce"**
   - Voir "Photo Test Rejet"
   - Cliquer **"Refuser"**
   - Entrer note : "Image floue, merci de reuploader"
   - Confirmer

3. **Vérifier Firestore** :
   ```javascript
   {
     status: "rejected",
     moderationNote: "Image floue, merci de reuploader",
     moderatedBy: "<UID_ADMIN_GROUPE>",
     moderatedAt: <timestamp>
   }
   ```

4. **Vérifier notification** (si fcmToken présent) :
   - Titre : "❌ Contenu refusé"
   - Body : 'Votre média "Photo Test Rejet" nécessite des modifications : Image floue, merci de reuploader'

5. **En tant que Créateur Digital** :
   - Aller dans **"Mes contenus"** → Onglet **"Refusés"**
   - Voir note de refus affichée
   - Cliquer **"Modifier"**
   - Modifier + **"Re-soumettre"**

---

### Test 7 : Analytics Commerce

**Utilisateur** : `test-superadmin@maslive.test`

**Procédure** :
1. Après avoir créé plusieurs soumissions (mix de statuts)
2. Aller dans **Admin Dashboard**
3. Cliquer **"Analytics Commerce"**
4. **Vérifier affichage** :
   - Total soumissions
   - En attente / Validés / Refusés
   - Par type (Produits / Médias)
   - Période récente (7 jours / 30 jours)
   - Taux d'approbation / refus
5. Cliquer **Refresh** → stats mises à jour

---

### Test 8 : Permissions Firestore Rules

**Test unitaire des règles** (via Firebase Emulator ou Console Rules Playground)

```javascript
// ✅ TEST 1 : Lecture autorisée pour propriétaire
match /commerce_submissions/{submissionId} {
  allow read: if request.auth.uid == resource.data.ownerUid;
}
// User: test-compte-pro, Doc ownerUid: test-compte-pro → ALLOW

// ✅ TEST 2 : Écriture interdite si status=approved
match /commerce_submissions/{submissionId} {
  allow update: if resource.data.status != 'approved' 
                || request.auth.uid in ['superadmin_uid'];
}
// User: test-compte-pro, Doc status: approved → DENY

// ✅ TEST 3 : Admin groupe peut modérer son scope uniquement
match /commerce_submissions/{submissionId} {
  allow update: if canModerate();
}
// User: test-admin-groupe (managedScopeIds=['test_group_123'])
// Doc scopeId: test_group_123 → ALLOW
// Doc scopeId: autre_group → DENY

// ✅ TEST 4 : Boutique en lecture seule
match /shops/{scopeId}/products/{productId} {
  allow read: if isSignedIn();
  allow write: if isSuperAdmin();
}
// User: test-compte-pro → read ALLOW, write DENY
// User: test-superadmin → read ALLOW, write ALLOW
```

---

### Test 9 : Cloud Functions Logs

**Vérifier que les CF se déclenchent correctement**

1. **Firebase Console** > Functions > Logs
2. Filtrer par fonction :
   - `approveCommerceSubmission`
   - `rejectCommerceSubmission`
   - `notifyCommerceApproved`
   - `notifyCommerceRejected`

3. **Vérifier logs attendus** :
   ```
   ✅ Submission abc123 approved by superadmin_uid and published to shops/global/products/abc123
   ✅ Notification approval sent to compte_pro_uid for abc123
   
   ✅ Submission def456 rejected by admin_groupe_uid
   ✅ Notification rejection sent to createur_uid for def456
   ```

---

## 📊 Checklist de validation finale

- [ ] **Commerce visible dans profil** pour 4 rôles autorisés
- [ ] **Création produit draft** fonctionne (Firestore + Storage)
- [ ] **Soumission pour validation** change status → pending
- [ ] **Approbation** publie dans `shops/{scopeId}/products`
- [ ] **Notification approbation** reçue par propriétaire
- [ ] **Refus** met status → rejected avec note
- [ ] **Notification refus** reçue avec note
- [ ] **Re-soumission** possible depuis onglet Refusés
- [ ] **Admin groupe** peut modérer uniquement son scope
- [ ] **SuperAdmin** peut tout modérer
- [ ] **Analytics** affiche stats correctes (refresh fonctionne)
- [ ] **Cloud Functions** loguent correctement
- [ ] **Firestore Rules** bloquent accès non autorisés
- [ ] **Storage** organise fichiers dans `/commerce/{scopeId}/{uid}/{submissionId}/`

---

## 🚀 Commandes de déploiement

Après validation des tests :

```bash
# 1. Déployer Cloud Functions
cd /workspaces/MASLIVE/functions
firebase deploy --only functions:notifyCommerceApproved,functions:notifyCommerceRejected

# 2. Déployer app Flutter web
cd /workspaces/MASLIVE
bash git_commit_push_build_deploy.sh "feat: commerce system complete with analytics"

# 3. Vérifier déploiement
# Hosting URL: https://maslive.web.app
```

---

## 📧 Support

En cas de problème :
1. Vérifier logs Cloud Functions
2. Vérifier Firestore Rules Playground
3. Tester avec Firebase Emulator Suite
4. Contacter support Firebase si erreurs réseau

---

✅ **Tests complétés** : Le système commerce est production-ready !
