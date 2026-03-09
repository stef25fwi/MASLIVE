# Depreciation Concrete de createMediaShopCheckout

## Objectif

Converger vers un seul flow media marketplace pour les achats photo et packs:

- panier: `carts/{uid}`
- commande: `orders/{orderId}`
- paiement: `createMediaMarketplaceCheckout`
- livraison: `media_entitlements/{entitlementId}`
- telechargement: `getMediaDownloadUrl`

## Etat actuel confirme

### Backend legacy encore actif

- `createMediaShopCheckout` dans [functions/index.js](functions/index.js#L2081)
- `createCheckoutSessionForOrder` dans [functions/index.js](functions/index.js#L1736)
- fallback webhook vers `users/{uid}/orders/{orderId}` dans [functions/index.js](functions/index.js#L2689)

### Front legacy encore branche

- appel callable legacy dans [app/lib/services/cart_service.dart](app/lib/services/cart_service.dart#L222)
- historique legacy dans [app/lib/pages/purchase_history_page.dart](app/lib/pages/purchase_history_page.dart#L107)
- route d'entree Media Shop dans [app/lib/shop/widgets/shop_drawer.dart](app/lib/shop/widgets/shop_drawer.dart#L80)

### Contrainte majeure

`createMediaShopCheckout` ne gere pas seulement des photos. Le callable supporte aussi des produits Storex via `productId`, confirmes dans [functions/index.js](functions/index.js#L2118). La suppression ne doit donc pas melanger migration media et commerce general.

## Cible fonctionnelle

### Domaine media

- tous les achats media passent par `createMediaMarketplaceCheckout`
- toutes les commandes media vivent dans `orders/{orderId}` avec `metadata.kind = media_marketplace_order`
- tous les droits de livraison passent par `media_entitlements`

### Domaine Storex

- les produits physiques ou boutique restent sur leur flow dedie
- aucun item Storex ne doit encore transiter par `createMediaShopCheckout`

## Plan par etapes

### Etape 0. Geler le legacy sans casser la prod

- conserver les endpoints legacy mais les marquer comme deprecies
- journaliser chaque appel legacy pour mesurer le trafic restant
- journaliser chaque fallback webhook vers `users/{uid}/orders/{orderId}`

Statut:

- fait pour l'instrumentation dans [functions/index.js](functions/index.js#L1749)
- fait pour l'instrumentation dans [functions/index.js](functions/index.js#L2094)
- fait pour l'instrumentation dans [functions/index.js](functions/index.js#L2695)

### Etape 1. Sortir tous les ecrans media du modele users/{uid}/orders

- remplacer l'entree Media Shop du drawer par l'entree marketplace
- rediriger l'historique photo vers `MediaDownloadsPage` ou une page hybride marketplace
- ne plus presenter `PurchaseHistoryPage` comme point d'entree media

Fichiers a modifier:

- [app/lib/shop/widgets/shop_drawer.dart](app/lib/shop/widgets/shop_drawer.dart#L80)
- [app/lib/pages/purchase_history_page.dart](app/lib/pages/purchase_history_page.dart#L107)
- [app/lib/main.dart](app/lib/main.dart#L379)

Critere de sortie:

- plus aucun parcours utilisateur media ne depend de `users/{uid}/orders`

### Etape 2. Separer clairement media et Storex dans le front

- retirer l'usage de `CartService.createCheckoutSession()` pour le media
- brancher les achats media sur `MediaCartController.checkout()`
- reserver `CartService` aux flux Storex uniquement

Fichiers a modifier:

- [app/lib/services/cart_service.dart](app/lib/services/cart_service.dart#L222)
- ecrans media legacy, notamment [app/lib/pages/media_shop_page.dart](app/lib/pages/media_shop_page.dart#L280)

Critere de sortie:

- aucun achat photo ne declenche `createMediaShopCheckout`

### Etape 3. Stopper la creation de nouvelles commandes media legacy

- une fois le front migre, faire echouer `createMediaShopCheckout` pour les items photo
- conserver temporairement seulement le support Storex si encore necessaire
- si `createCheckoutSessionForOrder` n'est plus appele par aucun ecran, le bloquer aussi

Implementation recommandee:

- rejeter le callable si un item `photoId` est detecte
- renvoyer un message explicite de migration vers media marketplace
- garder une periode de grace courte pour les sessions deja creees

Critere de sortie:

- zero nouvelle commande media dans `users/{uid}/orders`

### Etape 4. Migrer l'historique utile

- backfill des achats photo payes vers `media_entitlements` si necessaire pour conserver les telechargements
- distinguer les vraies commandes media des commandes Storex mixtes ou physiques
- migrer l'UI de consultation vers les collections marketplace

Script recommande:

- source: `users/{uid}/orders/*` avec `status == paid`
- cible: `media_entitlements`, eventuellement `orders` root si un historique unifie est voulu

Attention:

- ne pas migrer automatiquement les produits Storex
- ne pas supposer qu'un document legacy est purement media sans inspecter les items

### Etape 5. Supprimer le fallback backend

- retirer le fallback webhook `users/{uid}/orders/{orderId}`
- supprimer `createCheckoutSessionForOrder`
- supprimer `createMediaShopCheckout`
- supprimer les lectures `users/{uid}/purchases` si elles ne servent plus

Critere de suppression:

- plus aucun appel observe sur 30 jours
- plus aucune session Stripe legacy en attente
- migration historique terminee

## Ordre d'execution recommande

1. migrer les points d'entree UI media
2. migrer le checkout media sur `MediaCartController`
3. bloquer la creation de nouvelles commandes media legacy
4. migrer ou assumer la perte de l'ancien historique telechargeable
5. retirer les fallbacks webhook et les callables legacy

## Risques a surveiller

- confusion entre media et Storex dans le callable legacy mixte
- historique utilisateur casse si `PurchaseHistoryPage` reste branche sur `users/{uid}/orders`
- paiements Stripe en vol si suppression trop rapide du fallback webhook
- telechargements impossibles pour les anciens achats si aucun backfill entitlement n'est fait

## Definition of done

- aucun parcours media ne lit `users/{uid}/cart`
- aucun parcours media ne lit `users/{uid}/orders`
- aucun achat media n'appelle `createMediaShopCheckout`
- tous les telechargements media passent par `media_entitlements` et `getMediaDownloadUrl`
- le webhook Stripe ne traite plus le modele `users/{uid}/orders/{orderId}`