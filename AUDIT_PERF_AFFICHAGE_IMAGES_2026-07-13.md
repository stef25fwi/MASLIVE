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
