# AUDIT_SHOP — MASLIVE

Date: 2026-02-11

## Périmètre
Audit du module Boutique (Storex) côté Flutter + intégrations Firebase/Stripe associées:
- UI/Navigation: `StorexShopPage`, `CartPage`, pages checkout Storex, pages reviews/success.
- Données Firestore: produits, wishlist, panier, commandes, reviews.
- Sécurité: règles Firestore liées à `reviews`.

## Résumé (état actuel)
Les blocages principaux identifiés dans l’itération en cours étaient:
1) Routes Storex non branchées (navigation vers pages “payment complete / reviews / tracker” cassée).
2) Wishlist: action “Ajouter au panier” en stub (message “coming soon”).
3) Panier: manque de support `imagePath` (assets) dans l’ajout et la synchro Firestore.
4) Reviews: absence de règles explicites `products/{productId}/reviews/{reviewId}` => risque de `permission-denied`.
5) Cohérence commandes: coexistence de `users/{uid}/orders` (Storex) et `/orders` (module admin/orders). (En cours d’alignement.)

## Correctifs appliqués
### 1) Routes Storex réelles
- Objectif: garantir que `Navigator.pushNamed(StorexRoutes.*)` ouvre les vraies pages.
- Implémenté: routes Storex dans `routes:` pointent vers `PaymentCompletePage`, `ReviewsPage`, `AddReviewPage`, `OrderTrackerPage` avec validation d’arguments et page d’erreur dédiée.

Fichier:
- `app/lib/main.dart`

### 2) Wishlist → ajout panier (fonctionnel)
- Objectif: remplacer le stub “coming soon” par un vrai ajout panier.
- Implémenté: récupération du produit à partir de l’ID wishlist (`doc.id`) puis `CartService.instance.addProduct(...)`.
- Fallback de lecture produit: `shops/{shopId}/products/{productId}` puis `products/{productId}`.

Fichier:
- `app/lib/pages/storex_shop_page.dart`

### 3) Panier: support des images assets (`imagePath`)
- Objectif: éviter la perte d’images lorsque les produits utilisent `imagePath` (assets) au lieu de `imageUrl`.
- Implémenté:
  - `addProduct()` renseigne désormais `imagePath`.
  - `_loadFromFirestore()` et `_syncToFirestore()` lisent/écrivent `imagePath`.
  - Ajout utilitaire `addItemFromFields()` pour des ajouts depuis données partielles (ex: wishlist) si besoin.

Fichier:
- `app/lib/services/cart_service.dart`

### 4) Firestore Rules: reviews explicites
- Objectif: autoriser lecture publique et création par user authentifié des reviews Storex.
- Implémenté:
  - `match /products/{productId}/reviews/{reviewId}`: `read` public, `create` signé-in avec validations (uid/rating/comment/authorName), `update/delete` auteur ou admin master.
  - Même règle sous `shops/{shopId}/products/{productId}/reviews/{reviewId}` (au cas où certains produits ne vivent que sous `shops/...`).

Fichier:
- `firestore.rules`

### 5) Tâches VS Code
- Correction d’un `tasks.json` cassé (JSON invalide) qui pouvait gêner les tâches du workspace.

Fichier:
- `.vscode/tasks.json`

## Validation
- `flutter analyze` : OK (aucune issue).

## Points à finaliser / risques connus
1) **Commandes (schémas multiples)**
   - Storex checkout écrit dans `users/{uid}/orders`.
   - La page historique admin/utilisateur `OrdersPage` lit `/orders` (selon implémentation du module commandes).
   - Recommandation: stabiliser une source de vérité ou maintenir un miroir (si besoin admin).

2) **Champs attendus par la UI commandes Storex**
   - La page “My Orders” Storex affiche `orderNo`, `itemsCount`, etc.
   - Vérifier que le backend (callable + webhook) écrit bien ces champs ou adapter l’affichage à `doc.id` + `items.length`.

3) **Règles `shops/{shopId}/orders`**
   - Actuellement: `allow create: if true;` (très permissif).
   - À resserrer si ce chemin est utilisé (ex: imposer `isSignedIn()` + validation de structure).

## Checklist rapide “boutons critiques”
- Wishlist: “Add to cart” -> OK (ajout réel)
- Checkout: “Commander” -> dépend du device (PaymentSheet mobile)
- Success: navigation StorexRoutes.* -> OK (routes branchées)
- Reviews: lecture/écriture -> OK côté rules + repo

---
Si tu veux, je poursuis sur la normalisation des commandes (schéma `/orders` vs `users/{uid}/orders`) et la sécurisation de `shops/{shopId}/orders`.
