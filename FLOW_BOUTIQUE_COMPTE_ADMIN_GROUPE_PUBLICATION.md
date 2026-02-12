# Flow Boutique — compte admin_groupe → publication

Ce document décrit le flow **réel** (UI → Firestore → Cloud Functions → affichage boutique) pour publier un produit ou un média depuis un compte (ex: `admin_groupe`) jusqu’à sa visibilité côté utilisateur.

## 1) Boutique “source de vérité” côté utilisateur

Dans l’application, les routes “boutique” pointent explicitement sur `StorexShopPage`:
- Route `/boutique` → `StorexShopPage(shopId: "global", groupId: "MASLIVE")` : [app/lib/main.dart](app/lib/main.dart#L175-L193)
- Route `/shop` → `GroupShopPage(...)` qui retourne `StorexShopPage(...)` : [app/lib/main.dart](app/lib/main.dart#L165-L174) et [app/lib/pages/group_shop_page.dart](app/lib/pages/group_shop_page.dart#L1-L17)
- Route `/shop-ui` → `StorexShopPage(...)` : [app/lib/main.dart](app/lib/main.dart#L155-L163)

Conclusion: **la boutique “la plus aboutie” et actuellement branchée** = `StorexShopPage`.

## 2) Entrée UI “compte → commerce”

Sur le profil, la section Commerce est affichée si `_canSubmitCommerce` est vrai:
- Injection de `CommerceSectionCard` : [app/lib/pages/account_page.dart](app/lib/pages/account_page.dart#L160-L176)

La carte Commerce fournit 4 entrées:
- Ajouter un article → `CreateProductPage`
- Ajouter un média → `CreateMediaPage`
- Mes contenus → `MySubmissionsPage`
- Mes articles en ligne → `SuperadminArticlesPage`

Voir: [app/lib/widgets/commerce/commerce_section_card.dart](app/lib/widgets/commerce/commerce_section_card.dart#L1-L92)

## 3) Création produit/média (draft → pending)

### 3.1 Brouillon (draft)

**Produit**
- La création/édition sauvegarde un brouillon via `CommerceService.createDraftSubmission(...)` (ou update si édition).
- Champs de scope envoyés: `scopeType` + `scopeId` (avec fallback `global` si vide).

Voir le point d’appel côté UI:
- [app/lib/pages/commerce/create_product_page.dart](app/lib/pages/commerce/create_product_page.dart#L496-L575)

**Média**
- Même logique (create draft ou update), avec `mediaType`, `photographer`, etc.

Voir:
- [app/lib/pages/commerce/create_media_page.dart](app/lib/pages/commerce/create_media_page.dart#L90-L170)

### 3.2 Upload des médias (Storage)

Le flow upload côté UI appelle:
- `CommerceService.uploadMediaBytes(...)` (web) / `uploadMediaFiles(...)` (mobile)

Voir:
- Produit: [app/lib/pages/commerce/create_product_page.dart](app/lib/pages/commerce/create_product_page.dart#L430-L495)
- Média: [app/lib/pages/commerce/create_media_page.dart](app/lib/pages/commerce/create_media_page.dart#L100-L145)

Côté service, ces méthodes délèguent à `StorageService`:
- [app/lib/services/commerce/commerce_service.dart](app/lib/services/commerce/commerce_service.dart#L142-L214)

Note importante (risque d’orphelins): `deleteSubmission()` supprime un dossier `commerce/{scopeId}/{ownerUid}/{submissionId}`, alors que l’upload passe par une “structure organisée” (actuellement sous `media/...`). Si tu constates des fichiers qui restent après suppression, c’est probablement ici.

### 3.3 Soumission (pending)

Une fois le contenu prêt, l’écran appelle:
- `CommerceService.submitForReview(submissionId)` → met `status = pending` et timestamps.

Voir:
- Produit: [app/lib/pages/commerce/create_product_page.dart](app/lib/pages/commerce/create_product_page.dart#L720-L781)
- Média: [app/lib/pages/commerce/create_media_page.dart](app/lib/pages/commerce/create_media_page.dart#L245-L310)
- Service: [app/lib/services/commerce/commerce_service.dart](app/lib/services/commerce/commerce_service.dart#L73-L92)

## 4) Données Firestore: commerce_submissions

La collection “soumissions commerce” est la base du système A:
- `commerce_submissions/{submissionId}`

Écriture initiale (draft):
- [app/lib/services/commerce/commerce_service.dart](app/lib/services/commerce/commerce_service.dart#L22-L71)

Champs clés:
- `type`: `product` ou `media`
- `status`: `draft` → `pending` → `approved`/`rejected`
- `ownerUid`, `ownerRole`
- `scopeType`, `scopeId` (**scopeId = `global` si vide côté UI**)

## 5) Modération (système A: soumissions)

### 5.1 UI modération

La page admin de modération liste les soumissions en attente:
- `CommerceService.watchPendingSubmissions(...)`

Puis appelle:
- `CommerceService.approve(submissionId)`
- `CommerceService.reject(submissionId, note)`

Voir:
- [app/lib/admin/admin_moderation_page.dart](app/lib/admin/admin_moderation_page.dart#L1-L132)
- Callables: [app/lib/services/commerce/commerce_service.dart](app/lib/services/commerce/commerce_service.dart#L252-L316)

### 5.2 Autorisation réelle (backend)

La logique d’autorisation est appliquée dans la Cloud Function `approveCommerceSubmission` / `rejectCommerceSubmission`:
- Admin/superadmin/global: `isAdmin` ou `role in {admin, superadmin}`
- Admin groupe: `role == admin_groupe` ET `submission.scopeType == group` ET `managedScopeIds` contient `submission.scopeId`

Voir:
- [functions/index.js](functions/index.js#L2990-L3047)

## 6) Publication (backend) et visibilité boutique

### 6.1 Publication (écriture)

Sur approbation, la Function publie un document **dans la boutique**:
- `shops/{scopeId}/products/{submissionId}` ou `shops/{scopeId}/media/{submissionId}`

Voir:
- [functions/index.js](functions/index.js#L3049-L3078)

Important:
- Le doc publié contient `isActive` (pour les produits) mais **ne pose pas `moderationStatus`**.

### 6.2 Affichage boutique principale

`StorexRepo.base()` lit par défaut:
- `shops/{shopId}/products` avec `where('isActive' == true)`

Voir:
- [app/lib/pages/storex_shop_page.dart](app/lib/pages/storex_shop_page.dart#L100-L118)

Conséquence:
- Les produits publiés par le système A sont **visibles dans Storex** dès qu’ils sont approuvés (si `isActive = true`).

## 7) Système B en parallèle (incohérence)

Il existe un 2ᵉ circuit basé sur la collection root `/products`:
- Modération directe `/products` via `PendingProductsPage` (filtre `moderationStatus == pending`).

Voir:
- [app/lib/pages/pending_products_page.dart](app/lib/pages/pending_products_page.dart#L1-L70)

Et un schéma “root + miroir” géré par `ProductRepository`:
- Écrit en batch dans `/products` ET `/shops/{shopId}/products`
- Pose `moderationStatus` (par défaut `approved`)

Voir:
- [app/lib/services/commerce/product_repository.dart](app/lib/services/commerce/product_repository.dart#L1-L150)

Problème: **Système A (soumissions) et Système B (/products) ne se rejoignent pas**.
- A publie dans `shops/{scopeId}/products` (pas dans `/products`)
- B modère dans `/products` (et miroir shops), sans passer par `commerce_submissions`

Recommandation “meilleure boutique possible”:
- **Converger vers le système A** (`commerce_submissions` → Functions → `shops/{scopeId}/products`).
- Garder `PendingProductsPage` explicitement “legacy/admin-only” ou le retirer du parcours officiel (sinon on aura des états divergents).

## 8) Cohérence si tu réactives une boutique via collectionGroup('products')

La page `ShopBodyUnderHeader` (si utilisée) filtre strictement:
- `collectionGroup('products')` + `isActive == true` + `moderationStatus == approved`

Voir:
- [app/lib/pages/shop_body.dart](app/lib/pages/shop_body.dart#L40-L88)

Comme le système A ne pose pas `moderationStatus`, ces produits peuvent être **invisibles** dans cette UI.

Deux options de design:
1) “Le champ doit exister partout”: ajouter `moderationStatus: 'approved'` lors de la publication (système A).
2) “Tolérer champ absent”: changer l’UI (mais Firestore ne permet pas un `where == approved OR field missing` proprement en une requête).

Vu que la boutique principale est Storex, l’option la plus simple est: **standardiser les docs shops/*/products** (inclure `moderationStatus`).

## 9) Sécurité / règles Firestore

Les règles couvrent bien:
- `commerce_submissions`: create/update/read/delete, et modération scope-aware (admin_groupe + managedScopeIds): [firestore.rules](firestore.rules#L506-L647)
- `shops/{scopeId}/products`: lecture publique sur “produits publics”, écriture client interdite (réservée superadmin / service account): [firestore.rules](firestore.rules#L649-L689)

## 10) Vérification (checklist)

### Analyse Flutter
- Déjà OK dans ton contexte: `flutter analyze` renvoie exit code 0.

### Smoke test manuel
1) Compte `admin_groupe`:
- Profil → Commerce → “Ajouter un article” → enregistrer brouillon → “Soumettre pour validation”
- Vérifier dans “Mes contenus” que le status est `pending`.

2) Compte modérateur (admin/superadmin ou admin_groupe du bon scope):
- Ouvrir la page de modération → valider
- Vérifier que le doc `shops/{scopeId}/products/{submissionId}` est créé.

### Backend
- Contrôler les logs Functions au moment `approveCommerceSubmission` et la mise à jour `commerce_submissions` (`status: approved`, `publishedRef`, etc.).
