# Audit Mapbox vs FlutterMap (MASLIVE) — 2026-01-31

## TL;DR
- **Aucun conflit technique direct** entre Mapbox (natif / GL JS) et FlutterMap : ils ne partagent pas la même pile.
- Les **vrais risques** viennent de la **duplication** (token/config/style), des **imports web-only** (`dart:html`, `dart:js`) qui contaminent le code partagé, et d’une **multiplication de pages** qui font la même chose.
- Si l’objectif est d’activer **Flutter Web WASM**, **Mapbox GL JS (dart:html/js)** devra être remplacé (ex: FlutterMap sur web).

## Cartographie rapide
### Moteurs de carte
- **Mobile/Desktop (3D)** : Mapbox natif (`mapbox_maps_flutter`) — page home par défaut.
- **Web** : Mapbox GL JS via `HtmlElementView` + `dart:html`/`dart:js`.
- **2D (legacy/admin)** : FlutterMap (`flutter_map`, `latlong2`).

### Pages clés
- Home 3D (natif) : `HomeMapPage3D`
- Home web : `HomeMapPageWeb`
- Home 2D legacy : `HomeMapPage`

### Widgets web Mapbox GL JS
- Facade d’entrée : `app/lib/ui/widgets/mapbox_web_view.dart` (export conditionnel web vs stub)
- Implémentation web-only : `app/lib/ui/widgets/mapbox_web_view_widget_web.dart`
- Stub non-web : `app/lib/ui/widgets/mapbox_web_view_widget_stub.dart`

### Assistant admin “circuit”
- Builder : `app/lib/admin/assistant_step_by_step/build_circuit_map.dart`
- Implémentation web-only : `app/lib/admin/assistant_step_by_step/mapbox_web_circuit_map.dart`
- Stub non-web : `app/lib/admin/assistant_step_by_step/mapbox_web_circuit_map_stub.dart`

## Constats (problèmes réels)
1. **Duplication token/config**
   - Token Mapbox géré à plusieurs endroits (env + runtime + UI) → risque de divergence et de bugs subtils.
2. **Web-only qui fuit dans le code partagé**
   - Les imports `dart:html/js` sont incompatibles avec certains modes (notamment WASM) et doivent rester strictement isolés.
3. **Plusieurs écrans qui “font la map”**
   - Maintenance plus coûteuse, plus de chemins d’état (tracking, overlays, modes, etc.).
4. **WASM**
   - Les warnings “Wasm dry run findings” sont normaux tant qu’on utilise Mapbox GL JS via `dart:html/js`.

## Recommandation “10/10” (cible)
### 1) Une matrice claire : 1 plateforme = 1 moteur
- **Mobile/Desktop** : Mapbox natif (3D)
- **Web** :
  - Option A (actuel): Mapbox GL JS (dart2js) — pas WASM
  - Option B (objectif WASM): FlutterMap sur web (ou autre lib compatible WASM)
- **Admin/legacy** : FlutterMap uniquement (simple, stable)

### 2) Unifier la config carte
Créer un service unique (ex: `MapConfigService`) responsable de :
- token (env + runtime)
- styleUrl
- presets (zoom/pitch/bearing)
- feature flags (ex: `useMapboxGlOnWeb`)

### 3) Standardiser les “barrels”/exports conditionnels
- Un seul point d’entrée pour un widget (ex: `mapbox_web_view.dart`) →
  - web: vrai widget
  - non-web: stub
- Éviter d’importer directement des fichiers web-only depuis du code partagé.

### 4) Rationnaliser les pages
- Garder `/` = Home 3D (natif)
- Garder `/map-web` (debug/option)
- Garder `/map-2d` (legacy)
- Documenter clairement quel écran est “source de vérité”.

## Migration (safe steps)
1. Isoler tous les `dart:html/js` derrière des imports conditionnels/export conditionnels.
2. Remonter la config/token dans un service unique.
3. Définir une stratégie web (dart2js vs WASM).
4. Réduire la duplication UI (overlays/menus) via widgets partagés.

## Tests/validation conseillés
- `flutter analyze`
- `flutter build web --release` (dart2js)
- (optionnel) `flutter build web --wasm` une fois la stratégie web définie
