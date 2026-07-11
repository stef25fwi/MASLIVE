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

## Recommandations restantes (non appliquées — à arbitrer)

- **`media_gallery_maslive_instagram_page.dart`** : deux `StreamBuilder`
  distincts sur `watchCountries()` (l.886 et l.1514) → deux listeners identiques.
  Mutualiser en un seul stream partagé.
- **`_renderMarketPoiMarkers`** (Home) : reconstruit tout le `FeatureCollection`
  GeoJSON + réapplique visibilité/ordre à chaque snapshot POI. Pour un circuit
  live à forte fréquence, envisager un diff (ne réécrire que si le contenu a
  changé) et éviter `_bringMarketPoiLayersToFront` si l'ordre est inchangé.
- **Images réseau** : généraliser `StorageUrlCache` aux `Image.network` et
  envisager `cached_network_image` (cache disque) pour les galeries/boutique.
