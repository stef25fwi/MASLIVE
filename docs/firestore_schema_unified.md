# Firestore Unified Schema – SaaS Pro 2026 (MASLIVE)

## Décision d’architecture (implémentée)

Stratégie **B (pipeline explicite)** :
- `map_projects` = **source d’édition/draft** (source canonique)
- `marketMap` = **vue publiée** (lecture publique / carte)
- Synchronisation uniquement au `publish`

Objectifs:
- compatibilité progressive sans casser l’existant
- minimiser les writes
- IDs stables (`projectId`, `layerId`, `poiId`)

## Cartographie des usages existants

### `map_projects` (édition)
- Wizard Pro / entrée wizard:
  - `app/lib/admin/circuit_wizard_entry_page.dart`
  - `app/lib/admin/circuit_wizard_pro_page.dart`
  - `app/lib/admin/map_project_wizard_page.dart`
  - `app/lib/admin/map_projects_library_page.dart`
- route style pro persistence:
  - `app/lib/route_style_pro/services/route_style_persistence.dart`
  - `app/lib/route_style_pro/ui/route_style_wizard_pro_page.dart`

### `marketMap` (vue publique et outils admin)
- services et UI carte:
  - `app/lib/services/market_map_service.dart`
  - `app/lib/pages/default_map_page.dart`
  - `app/lib/pages/home_map_page_3d.dart`
  - `app/lib/ui/widgets/marketmap_poi_selector_sheet.dart`
- admin/debug/perimeter/poi wizard:
  - `app/lib/admin/mapmarket_projects_page.dart`
  - `app/lib/admin/marketmap_debug_page.dart`
  - `app/lib/admin/marketmap_perimeter_page.dart`
  - `app/lib/admin/poi_marketmap_wizard_page.dart`

## Schéma unifié recommandé

## 1) map_projects (source de vérité d’édition)

### `/map_projects/{projectId}`
- `groupId: string`
- `createdBy: string`
- `uid: string` (legacy compat)
- `status: "draft" | "published"`
- `version: number`
- `sourceOfTruth: "map_projects"`
- `activeDraftId: string?`
- `publishedRef: string?` (path marketMap)
- `current: map`
  - `name, description, countryId, eventId`
  - `route[]`
  - `perimeter[]`
  - `routeStyle{}`
  - `styleUrl?`
- `published: map`
  - `marketMapPath`
  - `publishedAt`
  - `publishedBy`
  - `publishedVersion`
- `editLock: {lockedBy, lockedAt, expiresAt}?`
- timestamps: `createdAt, updatedAt, publishedAt?`

#### Sous-collections
- `/map_projects/{projectId}/layers/{layerId}`
- `/map_projects/{projectId}/pois/{poiId}`
- `/map_projects/{projectId}/drafts/{draftId}`

### `/map_projects/{projectId}/drafts/{draftId}`
- `version`
- `createdAt, createdBy`
- `dataSnapshot`
  - route/perimeter/style
  - `layers[]`
  - `pois[]`
  - `poisSummary`
  - `stats`

## 2) marketMap (vue publiée)

### `/marketMap/{countryId}/events/{eventId}/circuits/{projectId|circuitId}`
- `publishedVersion`
- `publishedAt`
- `sourceProjectId`
- `route[]`, `perimeter[]`, `style{}`
- `layers[]`, `pois[]` (snapshot)
- sous-collections synchronisées:
  - `layers/{layerId}`
  - `pois/{poiId}`

## 3) audit

### `/audit_events/{eventId}`
- `at`
- `actorUid`
- `actorRole`
- `action`
- `target { projectId, groupId, draftId?, marketMapPath? }`
- `diffSummary { routePointsDelta, poiDelta, perimeterChanged, styleChangedKeys[] }`

## 4) templates

### `/circuit_templates/{templateId}`
- `name`
- `category`
- `defaultStyle`
- `defaultLayers[]`
- `defaultChecklist[]`
- `createdBy`
- `isGlobal`

## Implémentation réalisée (itération courante)

### Nouveaux services
- `app/lib/services/circuit_repository.dart`
  - lecture compatible (`map_projects` puis fallback `marketMap`)
  - save draft canonique
  - publish pipeline explicite `map_projects -> marketMap`
  - sync layers/pois avec upsert stable + delete diff
  - pagination POI (`listPoisPage`)
  - templates (`listTemplates`, `createProjectFromTemplate`)
- `app/lib/services/circuit_versioning_service.dart`
  - lock/unlock projet
  - save/list/restore drafts
- `app/lib/services/audit_logger.dart`
  - log batché actions critiques
- `app/lib/services/publish_quality_service.dart`
  - score 0..100 + checks bloquants

### Wizard Pro (UI)
- `app/lib/admin/circuit_wizard_pro_page.dart`
  - **Step 0 Template** (skippable)
  - step pré-publication basé sur `PublishQualityService`
  - bouton publish désactivé tant que `canPublish == false`
  - boutons versioning (`Sauvegarder version`, `Historique`)
  - sauvegarde et publication via repository/versioning

### Sécurité/Rules
- `firestore.rules`
  - règles dédiées `map_projects` / `drafts`
  - transitions de statut contrôlées (`draft -> published`)
  - validations taille arrays route/perimeter
  - collection `audit_events` et `circuit_templates`

### Indexes
- `firestore.indexes.json`
  - `drafts(createdBy, createdAt)`
  - `pois(layerId, createdAt)`
  - `audit_events(action, at)`

## Plan de migration progressive

### Phase 1 (compat lecture) – en place
- lecture prioritaire `map_projects.current`
- fallback `marketMap` si nécessaire

### Phase 2 (publish pipeline explicite) – en place
- publication pousse snapshot dans `marketMap`
- met à jour `publishedRef` et métadonnées de version

### Phase 3 (backfill)
- script backend recommandé:
  1. scanner `marketMap` existant
  2. créer/compléter `map_projects` manquants
  3. poser `sourceOfTruth="map_projects"`
  4. initialiser `version=1`, `current`, `published`

## Remarques
- Le pipeline côté app est opérationnel; une évolution backend Cloud Function peut être ajoutée plus tard si besoin d’immutabilité stricte côté publication.
- Les writes sont limités via batch + diff.
- Les IDs POI/layers sont conservés quand présents pour stabilité.
