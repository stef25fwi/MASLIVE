# Audit perf — Affichage instantané des pages + images

_Date : 2026-07-13 · Branche : `claude/stripe-payment-audit-j378j6`_

Objectif : affichage **instantané** des pages avec leurs images. Analyse du
pipeline d'affichage et implémentation d'un flux UI ultra-rapide.

---

## 1. Pipeline d'affichage — état analysé

Chemin type d'une image (carte produit / galerie / POI) :

```
Firestore doc (imageUrl / gs://)
   └─> résolution gs://->downloadURL  (StorageUrlCache, MÉMOIRE seule)
        └─> Image.network(url)        (décodage plein format, sans cacheWidth)
             └─> ImageCache Flutter    (plafond défaut 100 Mo / 1000 images)
```

Widgets centraux : `StorageImage` (utilisé dans **22 fichiers**), `SmartImage`
(galeries/grilles), plus des `Image.network` directs (`product_tile`,
`storex_shop_page`).

### Goulots identifiés

| # | Problème | Effet sur l'affichage |
|---|----------|-----------------------|
| 1 | **Cache `gs://`→URL en mémoire seule** (`StorageUrlCache`) | Chaque **démarrage à froid** refait un aller-retour réseau `getDownloadURL()` **avant** de télécharger l'image → latence visible, pas d'instantané |
| 2 | **`Image.network` sans `cacheWidth`** | Décodage pleine résolution même pour des vignettes → RAM élevée → **évictions** de l'ImageCache → re-décodages → jank en scroll |
| 3 | **ImageCache au plafond par défaut** (100 Mo/1000) | Réaffichage d'une image déjà vue = re-téléchargement/re-décodage |
| 4 | **Spinners animés en placeholder** (`CircularProgressIndicator`, `RainbowLoadingIndicator`) | Coût de peinture + effet « chargement » au lieu d'un rendu immédiat |
| 5 | **Pas de fondu / `gaplessPlayback`** | Flash blanc quand l'URL change ou pendant le décodage |

> À noter : sur **web** (cible Firebase Hosting), les **octets** des images sont
> déjà mis en cache par le navigateur (HTTP cache). Le ressenti « non instantané »
> vient donc surtout des points 1, 4 et 5 — tous corrigés ici.

---

## 2. Solution implémentée (zéro nouvelle dépendance)

Choix : optimiser le **widget central** + le **cache**, sans ajouter de package
(build garanti). Impact réparti sur toute l'app via `StorageImage`/`SmartImage`.

### a) Cache disque des résolutions `gs://`→URL — `utils/storage_url_cache.dart`
- Persistance via `shared_preferences` (localStorage sur web) : au démarrage à
  froid, `peek()` renvoie **immédiatement** l'URL connue → aucun aller-retour
  Storage avant l'image.
- `init()` charge le cache disque au boot ; write-through **debouncé** (400 ms)
  et **borné** (800 entrées) pour rester bon marché.

### b) Tuning global au boot — `main.dart`
- `ImageCache.maximumSizeBytes = 256 Mo`, `maximumSize = 2000` → beaucoup moins
  d'évictions → images déjà vues **réaffichées instantanément**.
- `StorageUrlCache.init()` lancé tôt dans `main()`.

### c) Widget central — `ui/widgets/storage_image.dart`
- **`cacheWidth` auto** = `width × devicePixelRatio` → décodage à la taille utile.
- **Placeholder léger** (aplat gris) au lieu du spinner → peinture instantanée.
- **Fondu à l'apparition** (`frameBuilder`, 200 ms) ; un cache-hit s'affiche sans
  animation.
- **`gaplessPlayback: true`** → plus de flash au changement d'URL.

### d) `ui/widgets/smart_image_widgets.dart` (galeries/grilles)
- `cacheWidth` calculé depuis les contraintes de layout ; placeholder léger ;
  fondu ; `gaplessPlayback`. Suppression du spinner arc-en-ciel coûteux.

### e) `Image.network` directs restants
- `shop/widgets/product_tile.dart` et `pages/storex_shop_page.dart` :
  `cacheWidth` + `gaplessPlayback` + fondu (skeleton conservé sur la tuile).

---

## 3. Résultat attendu

- **Démarrage à froid** : les images dont l'URL est déjà connue s'affichent sans
  requête préalable (plus de latence `getDownloadURL`).
- **Scroll listes/grilles** : décodage dimensionné + ImageCache élargi → fluide,
  sans re-décodage.
- **Navigation entre pages** : images déjà vues instantanées (mémoire) ; nouvelles
  images en fondu doux sur placeholder immédiat (pas de flash blanc, pas de spinner).

## 4. Prochaine marche (optionnelle, si natif prioritaire)

Sur **mobile natif**, ajouter un **cache disque des octets** d'image apporterait
l'instantané au 1er affichage après réinstallation. Solution standard :
`cached_network_image` (+ `flutter_cache_manager`) branché dans `StorageImage`.
Non retenu ici car (a) le web s'appuie déjà sur le cache HTTP navigateur et
(b) l'ajout de dépendance nécessite un `flutter pub get` à valider. Bascule
localisée : le seul point à changer serait le `Image.network` de `StorageImage`.

---

## 5. Passe qualité « Top » (2e itération)

Après la passe vitesse, une 2e passe cible la **qualité perçue** :

### a) Blur-up premium — `SmartImage`
La variante **thumbnail** est affichée immédiatement en **aperçu flou**
(`ImageFiltered` blur), puis remplacée par l'image nette en **crossfade**
(`AnimatedSwitcher`, 250 ms) dès qu'elle est décodée. Le `frameBuilder` couvre
tout le pré-affichage (téléchargement + décodage), donc l'utilisateur voit
toujours quelque chose de « plein cadre » — jamais de trou ni de spinner. Un
cache-hit s'affiche net instantanément (pas d'animation).

### b) Filtrage `FilterQuality.medium`
Par défaut sur `StorageImage`, `SmartImage`, `product_tile`, `_ImgRaw`. Le
rééchantillonnage lissé (mipmaps) rend les **photos réduites nettes** au lieu du
rendu bloc du mode `low`, pour un coût GPU négligeable sur du contenu statique.

### c) Precache des images voisines (galeries)
`ImageGallery` et la vue plein écran préchargent les pages **adjacentes**
(`precacheImage` sur index ±1) à l'ouverture et à chaque changement de page →
**swipe instantané**. Un util public `precacheNetworkImages(context, urls)` est
fourni pour précharger le 1er écran d'autres pages (ex. grille boutique).

### Résultat combiné
- Ouverture d'une fiche / galerie : aperçu net immédiat (cache) ou flou→net
  élégant, jamais de blanc.
- Swipe galerie : image suivante déjà prête.
- Photos scalées : nettes (medium) sans surcoût perceptible.

---

## 6. Correctif régression web (3e itération) — flash blanc onglets

**Symptôme signalé** : flash blanc au clic sur les icônes Boutique / Média
(et carte) de la bottom bar, apparu après les passes 1–2.

**Causes racines identifiées** :
1. La navigation par onglets fait un `pushReplacementNamed('/user-shell')` —
   la page est détruite et reconstruite à chaque clic (pré-existant).
2. **Sur Flutter web, `cacheWidth` (`ResizeImage`) était contre-productif** :
   il change la clé du cache image (les images déjà décodées sont re-décodées
   à chaque navigation) et le redimensionnement s'exécute **sur le thread UI**
   (pas d'isolate sur web) → jank pendant la construction des grilles.
3. **Les fondus d'apparition (200–250 ms)** retardaient la peinture des images :
   pendant l'animation, le fond blanc de la page transparaît → « flash blanc ».
4. ImageCache 256 Mo sur web : pression mémoire navigateur (pauses GC).

**Correctifs appliqués** (les gains des passes 1–2 sont conservés) :
- `cacheWidth`/`ResizeImage` **désactivés sur web** (gating `kIsWeb` centralisé
  dans `StorageImage`, `SmartImage`, `product_tile`, `_ImgRaw`,
  `precacheNetworkImages`) — conservés sur natif où ils réduisent la mémoire.
- **Suppression de tous les fondus d'apparition** : l'image peint dès sa
  première frame décodée. Le blur-up de `SmartImage` reste, mais en **swap
  instantané** (placeholder flou → image nette sans crossfade).
- ImageCache web ramené à 128 Mo / 1000 entrées (natif inchangé: 256 Mo / 2000).
- Conservés : cache disque des URLs `gs://`, `gaplessPlayback`,
  `FilterQuality.medium`, precache des galeries.

**Piste structurelle** : voir § 7 — implémentée dans la 4e itération.

---

## 7. Correctif structurel (4e itération) — retour au shell vivant

**Constat** : `UserFacingShellPage` garde déjà ses onglets en vie (cache
`_tabCache` + carte Mapbox conservée sous la pile) — les clics d'onglet **à
l'intérieur** du shell sont instantanés. Le flash résiduel venait exclusivement
des bottom bars **hors shell** (détail produit, checkout, routes `/boutique`…)
dont chaque clic faisait `pushReplacementNamed('/user-shell')` → reconstruction
complète d'un shell neuf (carte re-initialisée, onglets à froid).

**Correctif** :
- `UserFacingShellPage.switchToExistingShell(context, tab)` : si un shell
  vivant est présent dans la pile de navigation, `popUntil` vers sa route puis
  bascule d'onglet (`_selectTab`, logique commune avec la bar du shell) —
  retour **instantané**, pages et carte conservées.
- La bottom bar tente ce chemin avant son repli `pushReplacementNamed`
  (conservé pour le tout premier accès, quand aucun shell n'existe).
- **Pont léger `user_facing_shell_switch.dart`** : la bar (eager) n'importe pas
  la page shell (bibliothèque **différée**) — sinon le shell et ses 4 onglets
  seraient embarqués dans le bundle JS initial. Le shell installe un callback
  global à sa création et le retire à sa destruction.

**Effet** : après le premier affichage du shell, tous les clics Boutique /
Média / Home / Profil depuis n'importe quelle page sont sans reconstruction —
plus de flash blanc, carte Mapbox comprise.

---

## 8. Correctif régression (5e itération) — outils de carte visibles hors carte

**Symptôme signalé** : sur les pages Boutique / Média (et toute page hors
Home/Explorer), les contrôles de carte (zoom +/-, boussole, géolocalisation)
restent visibles en haut à gauche, alors qu'aucune carte ne devrait s'afficher.

**Cause racine** : ces contrôles sont ajoutés par **Mapbox GL JS**
(`NavigationControl` + `GeolocateControl`, dans `mapbox_bridge.js`) comme de
**vrais éléments DOM**, pas des widgets Flutter. Le shell garde la carte Home
vivante en permanence sous les autres onglets (`Positioned.fill` + overlay
opaque Flutter par-dessus — cf. § 7), mais l'overlay Flutter ne couvre que le
rendu Flutter : les contrôles DOM de Mapbox, positionnés dans le conteneur HTML
de la carte, ne sont pas concernés par cet overlay et restent visibles.
Bug préexistant (indépendant des passes 1–4), rendu plus visible depuis que la
navigation reste dans le même shell (§ 7) au lieu de détruire la carte à
chaque sortie.

**Correctif** :
- **JS** (`mapbox_bridge.js`) : nouvelle fonction `MasliveMapboxV2.setControlsVisible(containerId, visible)` qui bascule `visibility`/`pointer-events` sur les
  4 conteneurs de coin Mapbox (`.mapboxgl-ctrl-top-left/-top-right/-bottom-left/-bottom-right`) sans détruire ni redimensionner la carte.
- **Dart** : `MasLiveMapController.setNavControlsVisible(bool)` (API unifiée,
  no-op sur natif) ; branché côté web dans `maslive_map_web.dart`.
- **`DefaultMapPage`** : nouveau paramètre `mapVisibleListenable` — masque les
  contrôles quand la page n'est pas au premier plan, les réaffiche instantanément quand elle le redevient (sans recharger la carte).
- **`UserFacingShellPage`** : `ValueNotifier<bool> _homeMapForegroundVisible`
  synchronisé à chaque changement d'onglet (Home/Explorer visible vs Boutique/
  Média/Profil au premier plan), passé au `DefaultMapPage` mis en cache.

**Effet** : les contrôles de carte ne sont visibles que sur les pages Home/
Explorer ; ils disparaissent instantanément dès qu'un autre onglet passe au
premier plan, sans détruire la carte (le retour reste instantané, cf. § 7).

---

## 9. Audit chargement web instantané (6e itération) — page blanche au 1er tap

**Symptôme signalé** : en web, clic sur certaines icônes de la bottom bar
(Boutique/Média/Profil) → délai d'attente avec **page blanche** avant
affichage du contenu. Perçu comme un bug.

### Diagnostic du pipeline de chargement

Flutter web découpe le bundle en **chunks JS différés** (`deferred as` dans
`main.dart`). `UserFacingShellPage` — qui héberge Boutique/Média/Home/
Explorer/Profil — est **un seul gros chunk** (`user_shell`), non téléchargé
tant qu'aucune route ne l'a demandé. Deux problèmes cumulés :

1. **Préchauffe trop tardive et conditionnelle.** Un mécanisme de préchauffe
   existait déjà (`services/deferred_route_prefetch.dart`,
   `prefetchLikelyDeferredRoutes()`), mais il n'était déclenché que depuis
   `splash_wrapper_page.dart`, **après que la carte Mapbox soit prête** et le
   splash masqué (+ 120 ms). Sur un réseau lent, Mapbox peut mettre plusieurs
   secondes à charger — la préchauffe du chunk `user_shell` ne démarrait donc
   pas plus tôt, alors qu'elle n'a **aucune dépendance** avec la carte.
2. **Aucun retour visuel pendant le téléchargement.** `_DeferredLoader` (dans
   `main.dart`) affichait un `SizedBox.expand()` **totalement blanc/transparent**
   tant que le chunk n'était pas prêt — par design, pour éviter un flash de
   spinner sur les cas rapides. Mais si la préchauffe n'avait pas terminé (cas
   ci-dessus), l'utilisateur voyait un vrai blanc indéfini, lu comme un plantage.

Vérifié en complément : `StorexShopPage` affiche déjà des
`CircularProgressIndicator` pendant le chargement Firestore — le problème
n'est donc pas le contenu métier, mais bien le téléchargement du chunk JS
lui-même.

### Correctif

- **`main.dart`** : `prefetchLikelyDeferredRoutes()` est maintenant appelé dès
  le tout début de `_bootstrapInBackground()` (web uniquement), **avant**
  `Firebase.initializeApp` — en parallèle de l'init Firebase/Stripe/Mapbox, et
  totalement indépendant de la carte/splash. Le téléchargement du chunk
  `user_shell` (+ `cart`, `favorites`) démarre donc dès le premier instant de
  l'app, lui laissant largement le temps de se terminer avant que l'utilisateur
  n'atteigne la bottom bar (masquée tant que le splash n'a pas disparu).
  L'appel existant depuis le splash est conservé comme filet de sécurité
  (idempotent, sans coût).
- **`_DeferredLoader`** : remplace le blanc indéfini par
  `_DeferredLoadingFallback` — reste transparent pendant une courte grâce
  (220 ms, aucun flash sur le cas normal/rapide) puis affiche un indicateur de
  chargement discret si le téléchargement traîne réellement (réseau lent).
  Plus jamais de blanc qui se lit comme un bug, même sur le pire des cas.

### Effet attendu

- Réseau normal : le chunk `user_shell` est déjà en cache au moment du 1er tap
  → ouverture instantanée (0 délai perceptible) sur Boutique/Média/Profil.
- Réseau lent (rare) : un spinner discret apparaît après 220 ms au lieu d'un
  écran blanc — perçu comme un chargement normal, pas comme un bug.
