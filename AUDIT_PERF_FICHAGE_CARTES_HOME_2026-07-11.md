# Audit performance — Fichage des cartes, fluidité & page Home (2026-07-11)

Objectif : améliorer le **fichage des fiches POI (cartes)**, la **fluidité**,
réduire les **requêtes superflues en arrière-plan** et accélérer la **page Home
principale** (`home_map_page_3d.dart`).

## Constats & actions

### 1. ⚡ Fiche POI (polaroid) — résolution Storage refaite à chaque ouverture
**Constat** : `_PhotoArea` (`ui/widgets/polaroid_poi_sheet.dart`) appelait
`FirebaseStorage.refFromURL(...).getDownloadURL()` à **chaque** ouverture d'une
fiche dont l'image est en `gs://`. Rouvrir la même fiche = nouvel aller-retour
réseau, donc un flash de spinner à chaque fois.

**Action** :
- Nouveau cache mémoire process-lifetime `utils/storage_url_cache.dart`
  (`StorageUrlCache`) avec déduplication des requêtes concurrentes.
- La fiche fait d'abord un `peek()` **synchrone** : si l'URL est déjà résolue,
  l'image s'affiche **instantanément**, sans requête ni spinner.

**Gain** : affichage instantané en réouverture + suppression des requêtes
Storage redondantes. Cache réutilisable pour les cartes produit/boutique.

### 2. 🎞️ Peintre de grain polaroid — 2200 draw calls par frame
**Constat** : `_PolaroidGrainPainter.paint` appelait `canvas.drawPoints(...)`
**une fois par point** (jusqu'à 2200 appels + 2200 listes à un élément) à chaque
repaint de la fiche.

**Action** : un **seul** `drawPoints` batch avec la liste complète d'offsets.

**Gain** : ~2200× moins d'appels de dessin et d'allocations → fiche plus fluide
à l'ouverture/animation.

### 3. 🧹 Logs de debug exécutés en production à chaque snapshot POI
**Constat** : `debugPrint` **n'est pas** supprimé en release. Les blocs de log
POI dans `services/market_map_service.dart` (`watchVisiblePois`) et dans le
listener de `home_map_page_3d.dart` recalculaient plusieurs `.where().length`
sur toute la liste de POI **à chaque snapshot Firestore**, même en production.

**Action** : blocs gardés derrière `if (kDebugMode)`. Aucune itération ni log en
release.

**Gain** : moins de CPU sur le thread UI à chaque mise à jour de POI (live),
donc carte plus fluide.

## Points vérifiés — déjà sains (aucune action)

- **Menu « Carte »** : les streams `watchCountries/Events/Circuits/Layers` et
  `watchVisibleCircuitsIndex` vivent uniquement dans le bottom-sheet
  `marketmap_poi_selector_sheet.dart`. Menu fermé ⇒ **aucun** listener actif.
  Pas de requête permanente en arrière-plan.
- **`watchVisibleCircuitsIndex`** : une seule requête `collectionGroup('circuits')`
  en nominal ; le fan-out par pays/événement n'est qu'un **fallback** déclenché
  sur `permission-denied`/`failed-precondition`. Correct.
- **Home** : n'écoute que les POI du circuit sélectionné + positions groupe.
  Souscriptions correctement annulées dans `dispose()`.

## 4. 🔁 Streams `watchCountries()` recréés à chaque build (media gallery)
**Constat** : dans `_FiltersSheetMasliveState` et `_AddMediaSheetState`
(`media_gallery_maslive_instagram_page.dart`), `watchCountries()` était appelé
**directement** dans `stream:` du `StreamBuilder`. À chaque `build()`, un
**nouveau** stream Firestore était créé → `StreamBuilder` se réabonne
(annule/relance un listener) à chaque rebuild.

**Action** : stream mis en cache dans un champ `late final _countriesStream`
par State, passé au `StreamBuilder`.

**Gain** : un seul abonnement stable par sheet, plus de réabonnements Firestore
à chaque frame de saisie/rebuild.

## 5. 🗺️ Home — GeoJSON POI réécrit à chaque snapshot (garde-diff)
**Constat** : `_updateMarketPoiGeoJson` réécrivait la source Mapbox
(`setStyleSourceProperty`) à **chaque** snapshot POI, déclenchant un
re-render/re-cluster même quand le contenu était identique (fréquent sur
circuits live).

**Action** : garde-diff `_lastMarketPoiGeoJson` — on ne pousse la source que si
le JSON encodé a changé. Cache synchronisé à la (re)création de la source
(FeatureCollection vide) pour rester correct après changement de style. Le bloc
`debugPrint` associé est aussi gardé derrière `kDebugMode`.

**Gain** : suppression des réécritures/re-clusters inutiles → carte plus fluide
en live. Les changements réels (focus, ajout/retrait de POI) écrivent toujours.

## 6. 🖼️ Widget `StorageImage` réutilisable + `cacheWidth`
**Constat** : le pattern « résoudre `gs://` puis `Image.network` » n'existait
que dans la fiche polaroid ; les grilles de vignettes décodaient les images en
**pleine résolution** (mémoire élevée).

**Action** : `ui/widgets/storage_image.dart` — widget factorisé adossé à
`StorageUrlCache` (cache-hit synchrone, http/assets/gs:// gérés) avec
`cacheWidth`/`cacheHeight`. Adopté dans la grille `_MediaTileMaslive`
(`cacheWidth: 400`).

**Gain** : vignettes décodées à taille utile (moins de RAM, scroll plus fluide)
et résolution `gs://` cachée. Widget réutilisable pour boutique/galeries.

## 7. 🛍️ Adoption `StorageImage` aux cartes/vignettes boutique & listes
**Action** : retrofit des `Image.network` des grilles/listes vers `StorageImage`
(résolution `gs://` cachée + `cacheWidth` adapté + gestion d'erreur homogène) :

| Fichier | Contexte | `cacheWidth` |
| --- | --- | --- |
| `features/shop/widgets/rounded_product_card.dart` | carte produit (grille) | 400 |
| `features/shop/widgets/photo_grid_card.dart` | vignette photo (grille) | 400 |
| `features/bloom_art/presentation/widgets/bloom_art_item_card.dart` | carte œuvre | 500 |
| `widgets/cart/cart_item_tile.dart` | vignette panier 88px | 264 |
| `widgets/commerce/moderation_tile.dart` | vignette admin 80px | 240 |
| `widgets/commerce/submission_tile.dart` | vignette admin 60px | 180 |

**Gain** : décodage borné à la taille utile (mémoire ↓, scroll plus fluide),
plus la résolution `gs://` cachée. Les cartes sans gestion d'erreur en héritent
désormais (fallback propre).

Retrofit étendu (2ᵉ passe) aux surfaces galeries/marketplace/boutique :
`shop_media_gallery_page` (grille + aperçu dialogue), `media_photo_shop_page`
(grille), `product_management_page` (carte + carrousel), `boutique_page`
(vignette 66px), `media_marketplace_home_page` (5 couvertures), `storex_shop_page`
(vignette grille), `shop_body` (`filterQuality.high` préservé). `StorageImage`
gagne au passage les paramètres `alignment` et `filterQuality` pour rester un
drop-in fidèle.

> Non retrofité volontairement :
> - héros produit zoomable (`product_detail_page`, viewer plein écran) — pas de
>   `cacheWidth` pour préserver la qualité au zoom ×3 ;
> - `product_tile` (boutique) — conserve son skeleton animé + `alignment`
>   spécifiques ;
> - previews d'upload/picker (URL blob/locale, pas de bénéfice cache).

Retrofit étendu (3ᵉ passe) aux **surfaces admin** :
`admin_products_page` (carte + preview), `poi_edit_popup` (preview POI),
`pending_products_page` (3 vignettes), `superadmin_articles_page` (carte +
preview), `professional_articles_page` (vignette 80px),
`professional_article_form_page` (preview 200px), `group_profile_page`
(vignette 72px). Cache-hit `gs://` + décodage borné y compris côté back-office.

Vignette panier du checkout client (`maslive_ultra_premium_checkout_page`,
98×112, branche réseau uniquement — dispatch asset/http préservé) : `cacheWidth`
300.

## Recommandations restantes (non appliquées — à arbitrer)

- Retrofit `StorageImage` sur les `Image.network` restants au cas par cas
  (galeries plein écran, gestion produits) avec un `cacheWidth` adapté.
- Envisager `cached_network_image` (cache **disque**) pour la persistance
  inter-sessions — nécessite l'ajout de la dépendance + `flutter pub get`.
- `_bringMarketPoiLayersToFront` : ne réordonner que si l'ensemble des couches a
  changé.

> ⚠️ SDK Flutter absent de l'environnement d'édition : changements validés par
> relecture. Lancer `flutter analyze` / build avant merge.
