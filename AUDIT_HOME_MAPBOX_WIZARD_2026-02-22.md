# AUDIT — Home + Mapbox + câblage Wizard (2026-02-22)

## Périmètre

Audit ciblé sur :
- Page Home (routes principales, surtout Web)
- Carte Mapbox (Web: Mapbox GL JS via HtmlElementView + bridge JS ; Natif: mapbox_maps_flutter)
- Câblage avec le Wizard / MarketMap (édition périmètre/tracé, POIs visibles, preview maps)

Objectif : identifier pourquoi « initialisation Mapbox GL JS échoue » de façon intermittente et fiabiliser l’intégration Home ↔ Map ↔ Wizard.

## 1) Entrées & routes (constat)

Routes déclarées dans [app/lib/main.dart](app/lib/main.dart) :
- `/` → `DefaultMapPage` (page carte “par défaut”, semble être le Home principal)
- `/mapbox-web` → `MapboxWebMapPage` (page debug admin: Mapbox GL JS via HtmlElementView)
- `/map-3d` → alias historique vers `MapboxWebMapPage` (nom trompeur)
- `/map-web` → alias legacy vers `/` (évite d’avoir 2 “Home carte” différents)
- `HomeWebPage` existe mais n’est pas route “initiale” et semble plutôt legacy.

Conclusion : il y a **plusieurs Home “carte”** qui coexistent. En prod, selon la navigation (router/role), on peut atterrir sur des pages différentes (et donc sur des implémentations Mapbox différentes).

## 2) Architecture Map (MasLiveMap)

Façade unique : [app/lib/ui/map/maslive_map.dart](app/lib/ui/map/maslive_map.dart)
- `MasLiveMap` route automatiquement vers :
  - Web → `MasLiveMapWeb` ([app/lib/ui/map/maslive_map_web.dart](app/lib/ui/map/maslive_map_web.dart))
  - iOS/Android → `MasLiveMapNative` ([app/lib/ui/map/maslive_map_native.dart](app/lib/ui/map/maslive_map_native.dart))

Contrôleur unifié : [app/lib/ui/map/maslive_map_controller.dart](app/lib/ui/map/maslive_map_controller.dart)
- API: `moveTo`, `setStyle`, `setMarkers`, `setPolyline` (incl. segmentsGeoJson), `setPolygon`, `setEditingEnabled`, `fitBounds`, `setMaxBounds`, etc.

### 2.1 Web (MasLiveMapWeb)

Fichier: [app/lib/ui/map/maslive_map_web.dart](app/lib/ui/map/maslive_map_web.dart)
- HTML container via `platformViewRegistry.registerViewFactory`.
- Appel JS via `MasliveMapboxV2.init(containerId, token, optionsJson)` (interop `@JS('MasliveMapboxV2.init')`).
- Réception d’événements via `window.onMessage` et parsing JSON string (via `jsonDecode`).
- Erreurs remontées via `MASLIVE_MAP_ERROR` (reason+message) et affichage d’un écran d’erreur (avec diagnostic token masqué).
- Patch récent: retries sur erreurs transitoires `CONTAINER_NOT_FOUND` / `MAPBOXGL_MISSING`.

Fichier JS: [app/web/mapbox_bridge.js](app/web/mapbox_bridge.js)
- `window.MasliveMapboxV2.init()` fait des checks:
  - containerId non vide
  - conteneur DOM présent
  - `mapboxgl` présent
  - WebGL support
  - token présent
- Post vers Flutter: `MASLIVE_MAP_READY`, `MASLIVE_MAP_TAP`, `MASLIVE_MAP_ERROR`.

### 2.2 Natif (MasLiveMapNative)

Fichier: [app/lib/ui/map/maslive_map_native.dart](app/lib/ui/map/maslive_map_native.dart)
- Mapbox SDK natif (mapbox_maps_flutter)
- Token set via `MapboxOptions.setAccessToken(info.token)`
- Rendu polyline “pro”: support segments via style layers côté natif.

## 3) Gestion du token (constat)

Service central: [app/lib/services/mapbox_token_service.dart](app/lib/services/mapbox_token_service.dart)
Ordre de résolution :
1) `--dart-define=MAPBOX_ACCESS_TOKEN=...`
2) `--dart-define=MAPBOX_TOKEN=...` (legacy)
3) `window.__MAPBOX_TOKEN__` (Web)
4) SharedPreferences (`maslive.mapboxAccessToken` puis legacy)

Web: le token résolu est aussi recopié dans `window.__MAPBOX_TOKEN__` via [app/lib/utils/mapbox_token_web_web.dart](app/lib/utils/mapbox_token_web_web.dart)

Fichier [app/web/index.html](app/web/index.html)
- Charge Mapbox GL JS depuis `https://api.mapbox.com/...`.
- Initialise `window.__MAPBOX_TOKEN__ = ""` (vide au départ, normal)
- Ajoute `window.__MAPBOXGL_LOAD_STATUS__ = loading|loaded|error`.

⚠️ Point d’attention: les pages qui utilisent `getTokenSync()` *avant* que `warmUp()` n’ait fini peuvent voir un token vide, surtout sur Web si le token ne vient pas du build.

## 4) Câblage Wizard / MarketMap (constat)

### 4.1 Wizard “Pro” (édition périmètre + route)

- `CircuitWizardProPage` utilise `MasLiveMap` et `CircuitMapEditor`:
  - [app/lib/admin/circuit_wizard_pro_page.dart](app/lib/admin/circuit_wizard_pro_page.dart)
  - [app/lib/admin/circuit_map_editor.dart](app/lib/admin/circuit_map_editor.dart)

`CircuitMapEditor`:
- récupère le token via `MapboxTokenService.getTokenSync()`
- active l’édition via `controller.setEditingEnabled(enabled: ..., onPointAdded: ...)`
- évite le click-through web via `PointerInterceptor`

➡️ Ce flux est aligné avec la façade `MasLiveMap`.

### 4.2 Wizard “Entry / Nouveau circuit” (preview map)

- [app/lib/admin/circuit_wizard_entry_page.dart](app/lib/admin/circuit_wizard_entry_page.dart)
- Affiche une preview `MasLiveMap` + fait du géocodage Mapbox (`api.mapbox.com/geocoding/...`) avec `MapboxTokenService.getToken()`.

➡️ Dépend du token Mapbox pour un bonus UX (recentrage via geocoding), mais reste best-effort.

### 4.3 MarketMap (périmètre / couches / POIs)

- Sélecteur: [app/lib/ui/widgets/marketmap_poi_selector_sheet.dart](app/lib/ui/widgets/marketmap_poi_selector_sheet.dart)
- Données: [app/lib/services/market_map_service.dart](app/lib/services/market_map_service.dart)
- Home `DefaultMapPage` écoute `MarketMapService.watchVisiblePois` et compose des `MapMarker`.

➡️ MarketMap est bien câblé côté data Firestore → markers, mais son affichage dépend de la stabilité Mapbox.

## 5) Point critique: 2 implémentations Web Mapbox en parallèle

### Impl A (moderne)
- `MasLiveMapWeb` + `MasliveMapboxV2` ([app/lib/ui/map/maslive_map_web.dart](app/lib/ui/map/maslive_map_web.dart) + [app/web/mapbox_bridge.js](app/web/mapbox_bridge.js))
- Evénements: postMessage en JSON string + `MASLIVE_MAP_ERROR` structuré.

### Impl B (ancienne / spécifique circuits)
- `buildCircuitMap` choisit sur Web: `MapboxWebCircuitMap` ([app/lib/admin/assistant_step_by_step/build_circuit_map.dart](app/lib/admin/assistant_step_by_step/build_circuit_map.dart))
- `MapboxWebCircuitMap` s’appuie sur `window.masliveMapbox` ([app/web/mapbox_circuit.js](app/web/mapbox_circuit.js))
- Evénements: postMessage en objet JS `{type:'MASLIVE_MAP_TAP', ...}`
- Pas de `MASLIVE_MAP_ERROR` structuré, diagnostics faibles.

Ce double-stack crée :
- 2 APIs JS (`MasliveMapboxV2` vs `masliveMapbox`) et 2 formats d’événements (string JSON vs objet)
- 2 stratégies d’init/retry différentes
- des comportements différents quand le script Mapbox est bloqué/retardé

➡️ C’est la source la plus probable d’« init échoue » *selon* la page (Home vs Wizard vs MarketMap perimeter).

## 6) Causes probables de l’échec Mapbox GL JS (par ordre)

### P0 — Scripts Mapbox bloqués / non chargés
Symptôme:
- reason `MAPBOXGL_MISSING` (ou `__MAPBOXGL_LOAD_STATUS__='error'`)

Causes:
- Private DNS / filtrage réseau / adblock bloquant `https://api.mapbox.com`

Mitigation:
- Diagnostic UI déjà en place côté Impl A.
- Impl B ne diagnostique pas (à améliorer).

### P0 — Race DOM / HtmlElementView non attaché
Symptôme:
- reason `CONTAINER_NOT_FOUND` ou écran blanc intermittent (surtout mobile)

Mitigation:
- Impl A a maintenant un retry/attente DOM.
- Impl B fait un `Future.delayed(300ms)` et tente, plus fragile.

### P1 — Token invalide / restrictions Mapbox
Symptôme:
- `MAPBOX_RUNTIME_ERROR` (ex: “Invalid access token”) ou erreurs tiles/style.

Causes:
- mauvais token (secret au lieu de public)
- restrictions (URL autorisées / scopes)

### P1 — Token “pas encore chargé”
Symptôme:
- pages qui lisent `getTokenSync()` trop tôt (Web) → token vide.

Mitigation:
- appeler `await MapboxTokenService.warmUp()` avant d’exiger le token
- ou utiliser `getTokenInfo()` async dans le widget.

## 7) Recommandations

### P0 (à faire en premier)
1) **Unifier l’implémentation Web**: choisir une seule pile JS.
   - Reco: garder `MasliveMapboxV2` + `MasLiveMapWeb` (déjà diagnostiqué, multi-cartes, retry, erreurs structurées).
   - Migrer `buildCircuitMap`/`MapboxWebCircuitMap` vers `MasLiveMap` + `MasLiveMapController`.

2) **Harmoniser le format d’événements** (postMessage):
   - standardiser sur JSON string (comme Impl A) ou sur Map objet, mais pas les deux.

### P1 (fiabilisation)
3) Dans les pages Wizard/MarketMap qui dépendent du token, s’assurer que le token est prêt:
   - `await MapboxTokenService.warmUp()` (best-effort) au `initState` des pages critiques.

4) Ajouter la remontée d’erreurs runtime Mapbox dans Impl B si elle reste (token/style/tiles).

### P2 (nettoyage)
5) Réduire le nombre de pages “Home carte” (éviter `/`, `/map-web`, `/mapbox-web` en parallèle), ou clarifier leur rôle.

## 8) Fichiers impactés (référence rapide)

Home/pages:
- [app/lib/pages/default_map_page.dart](app/lib/pages/default_map_page.dart)
- [app/lib/pages/home_map_page_web.dart](app/lib/pages/home_map_page_web.dart)
- [app/lib/pages/mapbox_web_map_page.dart](app/lib/pages/mapbox_web_map_page.dart)

Map core:
- [app/lib/ui/map/maslive_map.dart](app/lib/ui/map/maslive_map.dart)
- [app/lib/ui/map/maslive_map_web.dart](app/lib/ui/map/maslive_map_web.dart)
- [app/lib/ui/map/maslive_map_native.dart](app/lib/ui/map/maslive_map_native.dart)
- [app/web/index.html](app/web/index.html)
- [app/web/mapbox_bridge.js](app/web/mapbox_bridge.js)
- [app/web/mapbox_circuit.js](app/web/mapbox_circuit.js)

Wizard / MarketMap:
- [app/lib/admin/circuit_wizard_pro_page.dart](app/lib/admin/circuit_wizard_pro_page.dart)
- [app/lib/admin/circuit_map_editor.dart](app/lib/admin/circuit_map_editor.dart)
- [app/lib/admin/circuit_wizard_entry_page.dart](app/lib/admin/circuit_wizard_entry_page.dart)
- [app/lib/admin/marketmap_perimeter_page.dart](app/lib/admin/marketmap_perimeter_page.dart)
- [app/lib/admin/assistant_step_by_step/build_circuit_map.dart](app/lib/admin/assistant_step_by_step/build_circuit_map.dart)
- [app/lib/admin/assistant_step_by_step/mapbox_web_circuit_map.dart](app/lib/admin/assistant_step_by_step/mapbox_web_circuit_map.dart)

---

### Proposition de prochaine étape (si tu valides)
- (Option A) Migration rapide: faire en sorte que `buildCircuitMap` utilise `MasLiveMap` sur Web (même pile JS partout).
- (Option B) Minimal: renforcer `MapboxWebCircuitMap` (retry DOM + diagnostic `MASLIVE_MAP_ERROR` + lecture token via `window.__MAPBOX_TOKEN__`).
