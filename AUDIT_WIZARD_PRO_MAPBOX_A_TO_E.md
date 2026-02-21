# 🧭 AUDIT Wizard Pro + Mapbox (A→E)

**Date**: 2026-02-21  
**Périmètre**: Wizard “Pro” admin (création/édition circuit) + infra Mapbox (web/natif) + POIs  
**Objectif**: état factuel + risques + plan + récap du dernier patch (POI GeoJSON + hit-testing) et de l’archivage hard.

---

## A) Architecture (où on en est)

### Wizard réellement utilisé ("prod")
- **Entrée**: page d’admin qui ouvre le wizard via `CircuitWizardEntryPage`.
  - Fichiers: app/lib/admin/admin_main_dashboard.dart, app/lib/admin/circuit_wizard_entry_page.dart
- **Wizard complet**: édition multi-étapes dans `CircuitWizardProPage`.
  - Fichier: app/lib/admin/circuit_wizard_pro_page.dart

### Données “source de vérité” (draft)
- **Document principal**: `map_projects/{projectId}` (brouillon courant + compat legacy si besoin).
- **Sous-collections**: `layers`, `pois`, et historique `drafts` (snapshots/versioning).
- **Accès & persistance**: centralisés dans `CircuitRepository`.
  - Fichier: app/lib/services/circuit_repository.dart

### Versioning & snapshots
- Gestion de snapshots `map_projects/{projectId}/drafts/{draftId}` + mécanisme de verrou (edit lock) orchestré par `CircuitVersioningService`.
  - Fichier: app/lib/services/circuit_versioning_service.dart

### Qualité (gating avant publish)
- `PublishQualityService` calcule un score + items bloquants (périmètre/route/style/layers/POIs) et le wizard s’en sert pour autoriser/empêcher la publication.
  - Fichier: app/lib/services/publish_quality_service.dart
  - Usage: app/lib/admin/circuit_wizard_pro_page.dart

### Publication (publish)
- Publication du draft vers l’arbre public MarketMap (doc circuit + sous-collections layers/pois).
  - Impl: `CircuitRepository` (méthodes de publish)
  - Fichier: app/lib/services/circuit_repository.dart

### Rendu Mapbox
- **API unifiée app**: `MasLiveMap` choisit web vs natif.
  - Fichier: app/lib/ui/map/maslive_map.dart
- **Natif**: `mapbox_maps_flutter` + annotations (markers/polyline/polygon) + layer/style pour POIs GeoJSON.
  - Fichier: app/lib/ui/map/maslive_map_native.dart
- **Web**: Mapbox GL JS via `HtmlElementView` + bridge + hit-testing POI.
  - Fichier: app/lib/ui/map/maslive_map_web.dart
- **Autre moteur web existant**: `MapboxWebView` (widget web séparé, utilisé dans d’autres pages).
  - Fichiers: app/lib/ui/widgets/mapbox_web_view*.dart

### Routing (point important)
- L’app utilise `GetMaterialApp(routes: ...)`.
- **Correction récente**: suppression d’une route trompeuse `'/admin/circuit-wizard/:projectId'` (ce format n’est pas un vrai pattern dans `routes:`) au profit d’un flux **EntryPage → push** interne.
  - Fichier: app/lib/main.dart

---

## B) Tableau d’état (✅/⚠️/❌)

✅ **Draft / save / versioning / publish**: cohérents et centralisés (Repository + Versioning + Quality).
- Fichiers: app/lib/admin/circuit_wizard_pro_page.dart, app/lib/services/circuit_repository.dart, app/lib/services/circuit_versioning_service.dart

✅ **Qualité bloquante avant publish**: `PublishQualityService` branché et utilisé côté UI.
- Fichier: app/lib/services/publish_quality_service.dart

✅ **POI hit-testing “Pro” utilisé par le wizard admin**: POIs rendus via GeoJSON + `queryRenderedFeatures` (web + natif) et callbacks `onPoiTap/onMapTap` branchés sur l’étape POI du wizard admin.
- Fichiers: app/lib/admin/circuit_wizard_pro_page.dart, app/lib/ui/map/maslive_map.dart, app/lib/ui/map/maslive_map_native.dart, app/lib/ui/map/maslive_map_web.dart

✅ **Dette “2 wizards Pro” réduite**: le wizard UI non branché a été **archivé hard** et exclu de l’analyse.
- Archive: app/_archive/ui/wizard/pro_circuit_wizard_page.dart
- Exclusion analyse: app/analysis_options.yaml (`_archive/**`)

⚠️ **Dualité Mapbox web**: cohabitation de `MasLiveMapWeb` (bridge + POI hit-test + sources/layers) et `MapboxWebView` (widget séparé). Cela peut générer des comportements différents selon les pages.
- Fichiers: app/lib/ui/map/maslive_map_web.dart + app/lib/ui/widgets/mapbox_web_view*.dart

⚠️ **Interop web**: certains imports web (`dart:html`, `dart:js`) sont désormais “deprecated” côté lints; ils sont actuellement ignorés de manière ciblée dans `MasLiveMapWeb`.
- Fichier: app/lib/ui/map/maslive_map_web.dart

---

## C) Top 10 écarts Mapbox / risques concrets (mise à jour)

1) **Deux moteurs web** (`MasLiveMapWeb` vs `MapboxWebView`) → bugs non reproductibles entre pages.
   - Constat (factuel): `MapboxWebView` est encore utilisé dans plusieurs écrans web, par ex.
     - `app/lib/pages/home_map_page_web.dart`
     - `app/lib/pages/tracking_live_page.dart`
     - `app/lib/pages/default_map_page.dart`
     - `app/lib/pages/add_place_page.dart`
     - `app/lib/admin/admin_circuits_page.dart`
     - `app/lib/admin/admin_pois_simple_page.dart`
     - `app/lib/admin/poi_assistant_page.dart`
   - Déjà migrés vers `MasLiveMap` (P1 en cours):
     - `app/lib/pages/home_web_page.dart`
     - `app/lib/pages/mapbox_web_map_page.dart`
     - `app/lib/pages/route_display_page.dart`
   - Impact: 2 piles d’implémentation (API/interop/capacités) ⇒ écarts de features (ex: TODO polylines sur certains écrans) et “ça marche ici mais pas là”.
   - Détection rapide: chercher `MapboxWebView` dans `app/lib/**.dart` pour lister les écrans à migrer.

2) **Couleurs/tailles POI hardcodées** (circle radius ~7px, bleu) → pas paramétrable par layer/style.
   - Constat (factuel): la couche POI utilise des valeurs fixes, notamment
     - Web (`MasLiveMapWeb`): `circle-radius: 7`, `circle-color: #0A84FF`, `circle-stroke-width: 2`, `circle-stroke-color: #FFFFFF`
       - Fichier: `app/lib/ui/map/maslive_map_web.dart`
     - Natif (`MasLiveMapNative`): `CircleLayer(circleRadius: 7.0, circleColor: 0xFF0A84FF, circleStrokeWidth: 2.0, circleStrokeColor: 0xFFFFFFFF)`
       - Fichier: `app/lib/ui/map/maslive_map_native.dart`
   - Impact: impossible d’exprimer un style par couche (ex: marché vs parking) ou de refléter un “état” (sélectionné / hover / cluster) sans recoder.
   - Next-step P2 (si besoin produit): exposer ces paramètres via l’API `MasLiveMapControllerPoi` (ou via un mini “POI style options”) et les dériver de `MarketMapLayer`/Style Pro.

3) **Rendu natif hybride**: route/polygone via annotations + POIs via layers de style → OK fonctionnel, mais limite certains styles avancés sur route (par rapport à un rendu 100% style-layer).

4) **Redondance publish layers/pois**: doc + sous-collections → risque de divergence si un consumer lit l’un et pas l’autre.
- Fichier: app/lib/services/circuit_repository.dart

5) **Limite Firestore `whereIn` (10)**: déjà contournée côté client quand nécessaire, mais peut surprendre et coûter en bande passante si les filtres grossissent.

6) **Preview web Style Pro**: web **partiellement** aligné (casing/glow/dash/opacité/cap/join + fitBounds), mais reste plus simple que le mobile sur certains effets (segments “rainbow/traffic/vanishing”).
  - UI: `app/lib/route_style_pro/ui/widgets/route_style_preview_map.dart`
  - API/options: `app/lib/ui/map/maslive_map_controller.dart` (`PolylineRenderOptions`)
  - Bridge web: `app/web/mapbox_bridge.js` (`MasliveMapboxV2.setPolyline`)

7) **Persistance Style Pro**: champs multiples / compat partielle → risque d’incohérence si migration partielle.

8) **Sécurité/roles stricts**: `map_projects` et `marketMap` écriture admin only → tout wizard “public” doit être read-only.

9) **Hit-testing dépend du layer**: si le layer n’est pas en place (style pas chargé / layer retiré), les taps POI redeviennent des taps carte.

10) **Interop web et dette technique** (`dart:html`/`dart:js`) → migration future probable vers `package:web` + `dart:js_interop` pour réduire le bruit lints.

---

## D) Plan de patch priorisé (P0/P1/P2)

### P0 (risque produit/maintenance) — ✅ FAIT
- **Trancher “un seul wizard”**: wizard admin = source of truth.
- **Archiver hard** le wizard UI non branché + exclure `_archive/**` de l’analyse.

### P1 (cohérence Mapbox web) — ⚠️ À FAIRE
- Objectif: supprimer la dualité **`MasLiveMapWeb`** (bridge “v2”) vs **`MapboxWebView`** (widget web séparé), qui crée des écarts de features et des bugs difficiles à reproduire.

- Option A (recommandée): **standardiser sur `MasLiveMapWeb`**
  - Pourquoi: API unifiée `MasLiveMap` (web+natif), support POIs GeoJSON + hit-test déjà intégré, et un seul point d’évolution.
  - Étapes minimales:
    - Recenser les écrans web qui utilisent `MapboxWebView`.
      - Inventaire initial (à confirmer via grep):
        - `app/lib/pages/home_map_page_web.dart`
        - `app/lib/pages/default_map_page.dart`
        - `app/lib/pages/add_place_page.dart`
        - `app/lib/pages/tracking_live_page.dart`
        - `app/lib/admin/admin_circuits_page.dart`
        - `app/lib/admin/admin_pois_simple_page.dart`
        - `app/lib/admin/poi_assistant_page.dart`
      - Déjà migrés (P1 en cours):
        - `app/lib/pages/home_web_page.dart`
        - `app/lib/pages/mapbox_web_map_page.dart`
        - `app/lib/pages/route_display_page.dart`
      - Note: ignorer les fichiers de type `*_backup.dart` dans la migration “produit”.
    - Remplacer ces usages par `MasLiveMap` quand l’API Phase 1 couvre le besoin (markers/polyline/polygon/style + callbacks).
    - Pour les besoins manquants, étendre l’API Phase 1 dans `MasLiveMapController` plutôt que réintroduire un second widget.

- Option B: **encapsuler `MapboxWebView` derrière la même API** (si certaines pages nécessitent absolument son impl)
  - Pourquoi: migration progressive, mais conserve un coût de maintenance tant que 2 moteurs existent.
  - Étapes minimales:
    - Créer un adaptateur qui expose les mêmes primitives que `MasLiveMapController`.
    - Faire pointer `MasLiveMap` web vers l’impl `MapboxWebView` (temporairement) pour éviter des divergences d’usage côté UI.

- Definition of Done (P1)
  - Tous les écrans “produit” web utilisent **un seul** moteur (aucune nouvelle dépendance à un 2ᵉ widget Mapbox).
  - Parité minimale validée: markers + polyline + polygon + POIs GeoJSON (source/layer) + hit-testing POI.
  - Analyse/CI: pas d’augmentation du bruit lints lié au web (et suppression des ignores quand migration `package:web` sera faite).

### P2 (Style Pro) — ✅ Clarifié (état actuel)
- **Déjà en place (web)**: rendu “route-like” via `MasLiveMapController.setPolyline(...)` avec options avancées (casing/glow/dash/opacité/cap/join + animation direction) utilisées par `RouteStylePreviewMap`.
  - UI: `app/lib/route_style_pro/ui/widgets/route_style_preview_map.dart`
  - Bridge: `app/web/mapbox_bridge.js` (layers `maslive_polyline_*`)
- **Reste simplifié vs mobile**: les effets basés sur des *segments* (rainbow/traffic/vanishing) sont rendus côté mobile via GeoJSON multi-features, mais ne sont pas (encore) reproduits sur web.
  - Conséquence: la preview web est fidèle sur “forme de route” (casing/glow/dash), mais pas sur les variations de couleur/opacity par segment.

---

## E) Next patch proposé (2–4 fichiers max, impact immédiat) — ✅ RÉALISÉ

**Objectif livré**: apporter le POI GeoJSON + hit-testing au wizard réellement utilisé (admin), au lieu de laisser la feature dans une page UI non branchée.

### Changements effectués
- **Wizard admin**: branchement de `MasLiveMapControllerPoi` + callbacks `onPoiTap/onMapTap` + rendu POIs via `setPoisGeoJson(...)`.
  - Fichier: app/lib/admin/circuit_wizard_pro_page.dart
- **Infra map**: ajout du contrôleur `MasLiveMapControllerPoi` (GeoJSON + callbacks).
  - Fichier: app/lib/ui/map/maslive_map.dart
- **Natif**: source/layer POIs + hit-test `queryRenderedFeatures` sur layer POI.
  - Fichier: app/lib/ui/map/maslive_map_native.dart
- **Web**: upsert source/layer POIs + hit-test via `queryRenderedFeatures` côté Mapbox GL JS.
  - Fichier: app/lib/ui/map/maslive_map_web.dart

### Nettoyage / dette
- Route littérale `'/admin/circuit-wizard/:projectId'` supprimée (évite un faux pattern dans `routes:`).
  - Fichier: app/lib/main.dart
- Wizard UI non branché archivé hard + exclu de l’analyse.
  - Archive: app/_archive/ui/wizard/pro_circuit_wizard_page.dart
  - Ancien chemin supprimé (ne fait plus partie du build): app/lib/ui/wizard/pro_circuit_wizard_page.dart
  - Exclusion: app/analysis_options.yaml

### Validation
- `flutter analyze --no-fatal-infos --no-fatal-warnings` : ✅ OK (No issues found)

---

## Notes
- Ce document est volontairement **factuel** et orienté “maintenabilité produit”.
- Toute référence à un “GoRouter / pathParameters” dans les docs anciennes doit être considérée comme **stale** si elle contredit `GetMaterialApp(routes: ...)`.
