# MasLiveMap - Système de Carte Unifié

## Architecture

### 📁 Fichiers créés

```
lib/ui/map/
├── maslive_map.dart              # Point d'entrée (choisit Web ou Native)
├── maslive_map_controller.dart   # API de contrôle unifiée
├── maslive_map_web.dart          # Implémentation Web (MapboxWebView)
└── maslive_map_native.dart       # Implémentation Native (mapbox_maps_flutter)
```

### 🎯 Principe

Un seul widget `MasLiveMap` qui :
- **Web** : Utilise `MapboxWebView` (Mapbox GL JS)
- **Mobile** : Utilise `MapWidget` (Mapbox Maps SDK natif)
- **Fallback** : Peut utiliser `flutter_map` si pas de token Mapbox

## Usage de base

### Simple (sans contrôleur)

```dart
MasLiveMap(
  initialLng: -61.533,
  initialLat: 16.241,
  initialZoom: 15.0,
  showUserLocation: true,
  userLng: -61.533,
  userLat: 16.241,
  onMapReady: () {
    print('Carte prête !');
  },
)
```

### Avec contrôleur (pour actions dynamiques)

```dart
class MyMapPage extends StatefulWidget {
  @override
  State<MyMapPage> createState() => _MyMapPageState();
}

class _MyMapPageState extends State<MyMapPage> {
  final _mapController = MasLiveMapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _goToLocation() {
    _mapController.moveTo(
      lng: -61.533,
      lat: 16.241,
      zoom: 17.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MasLiveMap(
        controller: _mapController,
        initialLng: -61.533,
        initialLat: 16.241,
        initialZoom: 15.0,
        onMapReady: () {
          // Carte prête, on peut utiliser le contrôleur
          _goToLocation();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToLocation,
        child: Icon(Icons.location_on),
      ),
    );
  }
}
```

## API du contrôleur

### Déplacer la caméra

```dart
controller.moveTo(lng: -61.533, lat: 16.241, zoom: 17.0);
```

### Afficher la position utilisateur

```dart
controller.setUserLocation(lng: -61.533, lat: 16.241);
```

### Afficher des POIs (lieux)

```dart
controller.renderPlaces([
  MapPlace(
    id: '1',
    lng: -61.533,
    lat: 16.241,
    name: 'Restaurant',
    category: 'food',
    onTap: () => print('Tapped!'),
  ),
]);
```

### Afficher un itinéraire

```dart
controller.renderRoute([
  MapPoint(-61.533, 16.241),
  MapPoint(-61.534, 16.242),
  MapPoint(-61.535, 16.243),
]);
```

### Afficher des groupes (tracking)

```dart
controller.renderGroups([
  MapGroup(
    id: 'group1',
    lng: -61.533,
    lat: 16.241,
    name: 'Groupe A',
    memberCount: 5,
    color: '#FF5733',
  ),
]);
```

## Migration d'un écran existant

### Avant (flutter_map)

```dart
FlutterMap(
  mapController: _mapController,
  options: MapOptions(
    initialCenter: LatLng(16.241, -61.533),
    initialZoom: 15.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    MarkerLayer(
      markers: [
        Marker(
          point: LatLng(16.241, -61.533),
          child: Icon(Icons.location_on),
        ),
      ],
    ),
  ],
)
```

### Après (MasLiveMap)

```dart
MasLiveMap(
  controller: _mapController,
  initialLng: -61.533,  // Attention: lng d'abord !
  initialLat: 16.241,
  initialZoom: 15.0,
  places: [
    MapPlace(
      id: '1',
      lng: -61.533,
      lat: 16.241,
      name: 'Mon lieu',
    ),
  ],
)
```

### ⚠️ Différences importantes

1. **Ordre lng/lat inversé** : MasLiveMap utilise (lng, lat) comme Mapbox, pas (lat, lng) comme flutter_map
2. **Pas de MapController** : Utiliser `MasLiveMapController` à la place
3. **Pas de children** : Utiliser les props `places`, `route`, `groups` à la place

## Étapes de migration

### Ordre recommandé

**Priorité A** (visible + critique)
1. ✅ `home_map_page_v3.dart` - Affichage principal
2. ⏳ `tracking_live_page.dart` - Suivi en temps réel
3. ⏳ `admin_tracking_page.dart` - Admin tracking

**Priorité B** (édition & circuits)
4. ⏳ `admin_circuits_page.dart`
5. ⏳ `route_display_page.dart`
6. ⏳ `route_drawing_page.dart`
7. ⏳ `circuit_draw_page.dart`
8. ⏳ `circuit_editor_workflow_page.dart`
9. ⏳ `map_admin_editor_page.dart`

**Priorité C** (POI)
10. ⏳ `add_place_page.dart`
11. ⏳ `admin_pois_simple_page.dart`

### Check-list par écran

- [ ] Remplacer `import 'package:flutter_map/flutter_map.dart'` par `import '../ui/map/maslive_map.dart'`
- [ ] Remplacer `MapController` par `MasLiveMapController`
- [ ] Remplacer `FlutterMap` par `MasLiveMap`
- [ ] Convertir `LatLng(lat, lng)` en `MapPoint(lng, lat)`
- [ ] Déplacer les markers vers `places: [...]`
- [ ] Déplacer les polylines vers `route: [...]`
- [ ] Tester sur Web ET Mobile

## TODO

### Fonctionnalités à implémenter

- [ ] Affichage des POIs (places) sur native
- [ ] Affichage des itinéraires (route) sur native
- [ ] Affichage des groupes (groups) sur native
- [ ] Support des markers personnalisés (icônes)
- [ ] Support des événements onLongPress
- [ ] Support du mode édition (dessin de circuits)
- [ ] Fallback vers flutter_map si pas de token Mapbox
- [ ] Cache des styles Mapbox

### Optimisations

- [ ] Lazy loading des annotation managers
- [ ] Pooling des markers
- [ ] Clustering automatique si trop de markers
- [ ] Prefetch des tiles pour offline

## Support

Pour toute question sur la migration :
1. Consulter ce doc
2. Regarder `home_map_page_3d.dart` (exemple de référence)
3. Tester sur Web d'abord (plus rapide à itérer)
