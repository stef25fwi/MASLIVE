# AUDIT — Fiche descriptive POI (Polaroid) + logique tap/click (2026-03-06)

## Scope
Cet audit couvre le flow complet :
1) rendu des POIs sur la carte Home (GeoJSON + layers)
2) hit-test / cliquabilité au tap
3) ouverture de la fiche descriptive sous forme de bottom sheet “Polaroid” (lecture)
4) cohérence avec la fiche d’édition admin (PoiEditPopup) qui produit les champs (image/meta/popupEnabled)

Objectif : UX “10/10 pro” (fiable, rapide, cohérente, et robuste aux données incomplètes).

---

## 1) Câblage actuel (vérifié)

### 1.1 Source des données “fiche” (POI → GeoJSON)
Dans la Home map, les POIs sont convertis en GeoJSON et injectés dans une source Mapbox runtime.

- Construction GeoJSON : [app/lib/pages/home_map_page_3d.dart](app/lib/pages/home_map_page_3d.dart) (méthode `_updateMarketPoiGeoJson`)
- Champs embarqués dans `properties` :
  - `type`, `name`, `desc`
  - `imageUrl` (depuis `poi.imageUrl` / `photoUrl` / `image`)
  - `address`, `openingHours` (string ou jsonEncode), `phone`, `website`, `instagram`, `facebook`, `whatsapp`, `email`, `mapsUrl`
  - `meta` (Map si dispo)

Point positif : `meta` est embarqué, ce qui permet la back-compat (ex: `meta.image.url`).

### 1.2 Rendu + hit-test
Les POIs sont rendus via des `CircleLayer` (un layer par type), filtrés sur `properties.type`.

- Setup layers : [app/lib/pages/home_map_page_3d.dart](app/lib/pages/home_map_page_3d.dart) (méthode `_ensureMarketPoiGeoJsonRuntime`)
- Hit-test : [app/lib/pages/home_map_page_3d.dart](app/lib/pages/home_map_page_3d.dart) (méthode `_onMapTap`)
  - `queryRenderedFeatures` sur les layerIds `mm_pois_layer__{type}`
  - gestion des clusters (zoom in)
  - anti-doublon d’ouverture (debounce + flag `_isPoiPopupShowing`)

### 1.3 Décision “cliquable” (popupEnabled)
- Règles centralisées : [app/lib/services/poi_popup_service.dart](app/lib/services/poi_popup_service.dart)
  - lit `meta.popupEnabled` puis fallback `rootPopupEnabled`
  - fallback par type : WC non cliquable par défaut

Point positif : une règle unique évite les divergences UI.

### 1.4 UI fiche descriptive (Polaroid)
- Bottom sheet : [app/lib/ui/widgets/polaroid_poi_sheet.dart](app/lib/ui/widgets/polaroid_poi_sheet.dart)
  - photo : `Image.network(url)`
  - cadre : overlay systématique `assets/images/frame_polaroid.webp`
  - CTA : Appeler / Itinéraire / Site / Fermer

---

## 2) Risques & bugs probables (observables en prod)

### P0 — "Photo ne se télécharge pas" dans la fiche Polaroid
Causes les plus probables côté lecture :
1) `imageUrl` vide dans les propriétés GeoJSON et `meta.image.url` absent.
   - `_updateMarketPoiGeoJson` ne complète pas `imageUrl` depuis `meta.image.url` (c’est corrigé au moment du tap, mais seulement si `meta` est correctement récupéré).
2) `meta` retourné par Mapbox en tant que string/valeur aplatie, ou partiellement perdu.
   - Le code gère `metaRaw is Map` ou `metaRaw is String` (JSON) : c’est bien.
   - Reste un risque: selon plateforme/SDK, les objets nested dans `properties` peuvent être retournés différemment.
3) URL non http(s) (ex: `gs://...`) : `Image.network` échoue.
   - Dans l’admin, on stocke normalement un download URL (`meta.image.url`), donc à vérifier via Firestore.

**Symptôme** : sur mobile, l’UI reste sur fallback (logo) ou affiche un placeholder après erreur.

### P0 — "POI non cliquable" (fiche ne s’ouvre pas)
Les causes typiques :
1) Le layer POI n’est pas visible : par défaut, `_applyPoiTypeVisibility` cache tous les POIs tant qu’une icône du menu vertical n’a pas été sélectionnée.
2) `popupEnabled=false` (par défaut sur WC) ou explicitement désactivé via meta.
3) `queryRenderedFeatures` renvoie un cluster ou une feature inattendue, et `res.first` choisit la mauvaise.

**Point d’attention** : choisir toujours `res.first` peut être fragile si plusieurs features se superposent (POI + label + preview). Un tri par “meilleure” feature serait plus robuste.

### P1 — Données “horaires” illisibles
`openingHours` est parfois `jsonEncode` d’un map/list, ce qui peut afficher un JSON brut dans la fiche.

### P1 — Vibe Polaroid “incomplète”
Dans l’admin, `meta.polaroid.angleDeg` et `meta.polaroid.grain` existent (voir `PoiEditPopup`), mais la fiche lecture ne les utilise pas.
Résultat : cadre polaroid OK, mais pas l’effet “photo physique” (tilt + grain léger).

### P2 — UX actions (web/mobile)
- `tel:` ne marche pas toujours sur web; aujourd’hui on affiche un SnackBar si `canLaunchUrl` échoue (OK), mais il manque une alternative (copier numéro).
- Bouton “Site” est seulement une icône (découvrabilité moyenne).

---

## 3) Recommandations — UX 10/10 pro

### P0 (fiabilité)
1) Normaliser la source photo : garantir que `imageUrl` est toujours un `https://` (downloadURL) côté Firestore.
2) Renforcer le choix de feature au tap : ne pas prendre systématiquement `res.first`.
   - option simple: filtrer les features qui ont `properties.type` non vide et/ou `properties.name` non vide.
3) Ajouter un log debug optionnel (gated `kDebugMode`) si on ouvre une fiche sans image alors que `meta.image` existe (détection d’incohérence).

### P1 (lisibilité + polish)
1) Présenter `openingHours` : si JSON, afficher une version “human readable” (ligne par jour, ou au minimum ne pas afficher le JSON brut).
2) Appliquer l’effet polaroid de `meta.polaroid` en lecture :
   - légère rotation (angleDeg clamp)
   - grain overlay léger (réutilisable)
   - rester strictement dans les tokens (pas de nouveaux styles/couleurs).

### P2 (accessibilité & conversion)
1) `Site` : passer de l’icône seule à un bouton tonal compact si place.
2) Ajouter `Semantics`/tooltips cohérents sur les CTA.

---

## 4) Points de vérification rapides (checklist)

### Données
- Un POI avec image doit avoir au moins l’un des champs :
  - `imageUrl` OU `metadata.image.url`
- `metadata.popupEnabled` doit être `true` pour les types que tu veux cliquables.

### Clickability
- Les POIs ne sont visibles et donc “tapables” que si une action du menu vertical est sélectionnée (filtre type).
- Les WC sont non cliquables par défaut (sauf override explicite).

### UI
- Le cadre polaroid provient de `assets/images/frame_polaroid.webp`.

---

## 5) Fichiers clés
- Tap/click + GeoJSON POI: [app/lib/pages/home_map_page_3d.dart](app/lib/pages/home_map_page_3d.dart)
- Règles cliquabilité: [app/lib/services/poi_popup_service.dart](app/lib/services/poi_popup_service.dart)
- Fiche lecture Polaroid: [app/lib/ui/widgets/polaroid_poi_sheet.dart](app/lib/ui/widgets/polaroid_poi_sheet.dart)
- Fiche édition admin (source des champs): [app/lib/admin/poi_edit_popup.dart](app/lib/admin/poi_edit_popup.dart)
