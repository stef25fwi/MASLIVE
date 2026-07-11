# Configuration « connue bonne » — Affichage carte + POIs (2026-07-11)

État validé : carte Mapbox affichée, POIs visibles, `flutter analyze` **0 issue**.
À utiliser comme point de retour sûr si l'affichage des POIs régresse.

## Point de retour git

- **Commit** : `266d0da` — *style: clear analyzer info lints…*
- **Tag** : `poi-display-ok-2026-07-11`

Revenir à cet état exact à tout moment :

```bash
git fetch --tags
git checkout poi-display-ok-2026-07-11      # état détaché pour inspecter
# ou, pour repartir de cet état sur main :
git checkout main && git reset --hard poi-display-ok-2026-07-11
```

## Lancement reproductible

```bash
cd /workspaces/MASLIVE
export MAPBOX_ACCESS_TOKEN="pk.xxxx"     # ton token Mapbox public
./run_web_local.sh                       # port auto (8080, repli 8090…)
```

Le script `run_web_local.sh` gère : PATH Flutter, lecture du token
(`$MAPBOX_ACCESS_TOKEN` ou `.env`), repli de port si occupé, et les flags
`--dart-define` requis. **Le token n'est jamais committé** (`.env` est gitignoré).

Commande brute équivalente :

```bash
cd app
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
```

## Comment l'affichage des POIs fonctionne (invariants à préserver)

Chemin de données → rendu, dans `lib/pages/home_map_page_3d.dart` :

1. **Sélection circuit** (`_marketPoiSelection`) : pays + événement + circuit.
   Sans circuit sélectionné → aucun POI (comportement voulu).
2. **Stream POIs** : `MarketMapService.watchVisiblePois(countryId, eventId,
   circuitId, layerIds)` (`lib/services/market_map_service.dart`).
   Ne garde que les POIs `isVisible == true` et dont le `layerId`/`type`
   correspond au filtre.
3. **Rendu GeoJSON** : `_updateMarketPoiGeoJson()` pousse la
   `FeatureCollection` dans la source Mapbox `mm_pois_src`, rendue par les
   couches `mm_pois_layer__<type>` (visit/food/wc/parking/assistance/market).
4. **Visibilité par type** : `_applyPoiTypeVisibility()`.
   ⚠️ **Par défaut aucun POI n'est affiché** : ils n'apparaissent qu'après clic
   sur une icône du menu vertical (Visiter / Food / WC / …). C'est voulu.
5. **Garde-diff** : `_lastMarketPoiGeoJson` évite de réécrire la source si le
   contenu n'a pas changé. Il est **remis à zéro (FeatureCollection vide) à la
   (re)création de la source** dans `_ensureMarketPoiGeoJsonRuntime()` — ce qui
   garantit que les POIs sont bien repoussés après un changement de style.

## Checklist « les POIs ont disparu »

Vérifier dans l'ordre :

1. **Un filtre est-il sélectionné ?** Sans clic sur une icône du menu vertical,
   c'est normal qu'il n'y ait aucun POI (invariant #4).
2. **Circuit publié + visible ?** `status == 'published'` et `isVisible`/`visible`
   au niveau du circuit (Firestore `marketMap/{country}/events/{event}/circuits`).
3. **POIs `isVisible == true` ?** dans la sous-collection `…/circuits/{id}/pois`.
4. **`layerId`/`type` du POI cohérent** avec le filtre cliqué (mapping dans
   `_normalizeMarketPoiTypeCandidate`).
5. **Token Mapbox valide** (sinon la carte elle-même ne se charge pas → 401).
6. **Garde-diff** : si tu modifies `_updateMarketPoiGeoJson`, garde la remise à
   zéro de `_lastMarketPoiGeoJson` à la création de source, sinon les POIs
   peuvent ne pas réapparaître après un changement de style.
7. En dernier recours, revenir au tag `poi-display-ok-2026-07-11` (ci-dessus)
   et comparer le diff.
