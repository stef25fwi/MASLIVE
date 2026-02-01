# MasLiveMap - API Phase 1 (Mapbox Unique)

## 📋 Vue d'ensemble

**MasLiveMap** est le widget carte unifié MASLIVE utilisant Mapbox :
- **Web** : Mapbox GL JS via HtmlElementView  
- **Mobile** : mapbox_maps_flutter natif (iOS/Android)

✅ **Phase 1 complète** : API réutilisable pour affichage + édition

---

## 🚀 Usage basique

```dart
import 'package:masslive/ui/map/maslive_map.dart';
import 'package:masslive/ui/map/maslive_map_controller.dart';

class MyMapPage extends StatefulWidget {
  @override
  State<MyMapPage> createState() => _MyMapPageState();
}

class _MyMapPageState extends State<MyMapPage> {
  final _controller = MasLiveMapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MasLiveMap(
        controller: _controller,
        initialLat: 16.241,
        initialLng: -61.533,
        initialZoom: 13.0,
        onMapReady: (controller) {
          // Carte prête, utiliser controller
          _onMapReady();
        },
        onMapTap: (point) {
          print('Tap: ${point.lat}, ${point.lng}');
        },
      ),
    );
  }

  Future<void> _onMapReady() async {
    // Exemple : afficher des marqueurs
    await _controller.setMarkers([
      MapMarker(
        id: 'start',
        lat: 16.241,
        lng: -61.533,
        label: 'Départ',
        color: Colors.green,
      ),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## 🎯 API MasLiveMapController

### 📍 Caméra / Navigation

```dart
// Déplacer la caméra (animé par défaut)
await controller.moveTo(
  lat: 16.241,
  lng: -61.533,
  zoom: 15.0,
  animate: true,  // false pour saut instantané
);

// Changer le style de carte
await controller.setStyle('mapbox://styles/mapbox/satellite-streets-v12');
```

**Styles Mapbox disponibles** :
- `mapbox://styles/mapbox/streets-v12` (défaut)
- `mapbox://styles/mapbox/outdoors-v12` (sentiers)
- `mapbox://styles/mapbox/satellite-streets-v12` (satellite + routes)
- `mapbox://styles/mapbox/satellite-v9` (satellite pur)
- `mapbox://styles/mapbox/dark-v11`, `light-v11`

---

### 📌 Marqueurs (Markers)

```dart
// Afficher des marqueurs (remplace les existants)
await controller.setMarkers([
  MapMarker(
    id: '1',
    lat: 16.241,
    lng: -61.533,
    label: 'Point A',
    color: Colors.blue,
    size: 1.5,  // Taille relative (1.0 = défaut)
  ),
  MapMarker(
    id: '2',
    lat: 16.245,
    lng: -61.540,
    label: 'Point B',
    color: Colors.red,
  ),
]);

// Effacer tous les marqueurs
await controller.setMarkers([]);
```

---

### 📏 Polylignes (Trajets / Parcours)

```dart
// Afficher un parcours
await controller.setPolyline(
  points: [
    MapPoint(-61.533, 16.241),
    MapPoint(-61.535, 16.243),
    MapPoint(-61.538, 16.246),
  ],
  color: Colors.blue,
  width: 4.0,
  show: true,
);

// Masquer la polyligne
await controller.setPolyline(
  points: [],
  show: false,
);
```

---

### 🔷 Polygones (Zones / Circuits fermés)

```dart
// Afficher une zone
await controller.setPolygon(
  points: [
    MapPoint(-61.533, 16.241),
    MapPoint(-61.535, 16.241),
    MapPoint(-61.535, 16.243),
    MapPoint(-61.533, 16.243),
    MapPoint(-61.533, 16.241),  // Fermer le polygone
  ],
  fillColor: Colors.blue.withOpacity(0.3),
  strokeColor: Colors.blue,
  strokeWidth: 2.0,
  show: true,
);

// Masquer le polygone
await controller.setPolygon(
  points: [],
  show: false,
);
```

---

### 📍 Position utilisateur

```dart
// Afficher la position utilisateur
await controller.setUserLocation(
  lat: 16.241,
  lng: -61.533,
  show: true,
);

// Masquer
await controller.setUserLocation(
  lat: 0,
  lng: 0,
  show: false,
);
```

---

### ✏️ Mode Édition (Dessin interactif)

```dart
// Activer le mode édition
List<MapPoint> _points = [];

await controller.setEditingEnabled(
  enabled: true,
  onPointAdded: (lat, lng) {
    setState(() {
      _points.add(MapPoint(lng, lat));
    });
    // Mettre à jour la polyligne en temps réel
    controller.setPolyline(points: _points);
  },
);

// Désactiver le mode édition
await controller.setEditingEnabled(enabled: false);
```

---

### 🗑️ Nettoyage

```dart
// Effacer toutes les annotations (markers, polylines, polygons)
await controller.clearAll();
```

---

## 🔧 Configuration Mapbox Token

Le token Mapbox est chargé automatiquement via `MapboxTokenService` :

1. **--dart-define** (priorité haute)
   ```bash
   flutter build web --dart-define=MAPBOX_ACCESS_TOKEN=pk.ey...
   ```

2. **SharedPreferences** (runtime, via UI)
   - Utilisateurs peuvent configurer le token dans l'app

3. **Fallback** : affiche message d'erreur si aucun token

---

## 📦 Exemple complet : Page tracking live

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:masslive/ui/map/maslive_map.dart';
import 'package:masslive/ui/map/maslive_map_controller.dart';

class LiveTrackingPage extends StatefulWidget {
  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  final _controller = MasLiveMapController();
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tracking Live')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('groupLocations').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data!.docs;
          _updateMarkersFromGroups(groups);

          return MasLiveMap(
            controller: _controller,
            initialLat: 16.241,
            initialLng: -61.533,
            initialZoom: 12.0,
            onMapReady: (_) {
              _updateMarkersFromGroups(groups);
            },
          );
        },
      ),
    );
  }

  Future<void> _updateMarkersFromGroups(List<QueryDocumentSnapshot> groups) async {
    final markers = groups.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final position = data['position'] as GeoPoint;
      return MapMarker(
        id: doc.id,
        lat: position.latitude,
        lng: position.longitude,
        label: data['name'] ?? doc.id,
        color: Colors.green,
      );
    }).toList();

    await _controller.setMarkers(markers);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## 📦 Exemple : Éditeur de parcours

```dart
class RouteEditorPage extends StatefulWidget {
  @override
  State<RouteEditorPage> createState() => _RouteEditorPageState();
}

class _RouteEditorPageState extends State<RouteEditorPage> {
  final _controller = MasLiveMapController();
  final List<MapPoint> _points = [];
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dessiner un parcours'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.done : Icons.edit),
            onPressed: _toggleEditing,
          ),
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: _clearRoute,
          ),
        ],
      ),
      body: MasLiveMap(
        controller: _controller,
        initialLat: 16.241,
        initialLng: -61.533,
        initialZoom: 13.0,
        onMapReady: (_) {
          _controller.setEditingEnabled(enabled: _editing, onPointAdded: _onPointAdded);
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.save),
        onPressed: _saveRoute,
      ),
    );
  }

  void _toggleEditing() async {
    setState(() {
      _editing = !_editing;
    });
    await _controller.setEditingEnabled(
      enabled: _editing,
      onPointAdded: _onPointAdded,
    );
  }

  void _onPointAdded(double lat, double lng) {
    setState(() {
      _points.add(MapPoint(lng, lat));
    });
    _controller.setPolyline(points: _points, color: Colors.blue);
  }

  void _clearRoute() async {
    setState(() {
      _points.clear();
    });
    await _controller.clearAll();
  }

  void _saveRoute() async {
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun point à enregistrer')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('routes').add({
      'points': _points.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Parcours enregistré')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## ✅ Phase 1 — Bilan

| Fonctionnalité | Web | Mobile | Status |
|---------------|-----|--------|--------|
| Affichage carte | ✅ | ✅ | OK |
| moveTo (caméra) | ✅ | ✅ | OK |
| setStyle | ✅ | ✅ | OK |
| setMarkers | ✅ | ✅ | OK |
| setPolyline | ✅ | ✅ | OK |
| setPolygon | ✅ | ✅ | OK |
| setUserLocation | ⚠️ | ✅ | Partial (rebuild web) |
| setEditingEnabled | ✅ | ✅ | OK |
| clearAll | ✅ | ✅ | OK |

---

## 🔜 Phase 2 — Migration pages admin

**Ordre conseillé** :

1. ✅ **admin_tracking_page.dart** (simple : markers live)
2. **admin_circuits_page.dart** (polyline + markers)
3. **map_admin_editor_page.dart** (édition)
4. **route_drawing_page.dart** / **circuit_draw_page.dart** (workflow dessin)

**Avantage Phase 1** : toutes les pages utilisent la même API, plus besoin de `MapboxWebView` direct.

---

## 📚 Fichiers créés

- `lib/ui/map/maslive_map.dart` - Widget unifié
- `lib/ui/map/maslive_map_controller.dart` - API contrôleur
- `lib/ui/map/maslive_map_native.dart` - Implémentation mobile
- `lib/ui/map/maslive_map_web.dart` - Implémentation web

**Import minimal** :
```dart
import 'package:masslive/ui/map/maslive_map.dart';
import 'package:masslive/ui/map/maslive_map_controller.dart';
```

---

## 🐛 Debugging

### Web : "Token Mapbox manquant"
- Vérifier `index.html` contient mapbox-gl.js + mapbox-gl.css
- Configurer token via `--dart-define` ou SharedPreferences

### Mobile : "Erreur annotations"
- Vérifier MapboxOptions.setAccessToken() appelé avant MapWidget
- Token valide format `pk.ey...`

### Conflits latitude/longitude
- **Convention MasLiveMap** : (lng, lat) pour setMarkers/moveTo
- **MapPoint** : (lng, lat)
- **Firestore GeoPoint** : (latitude, longitude) ⚠️ ordre inversé

---

**Prêt pour Phase 2** : migrer admin_tracking_page.dart vers MasLiveMap ! 🎉
