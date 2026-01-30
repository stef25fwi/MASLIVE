📋 CONFIGURATION HOME_MAP_PAGE - COMMIT 0b19da0
============================================================

## Informations du commit
Commit: 0b19da08850b0a8c8f0620c5dce05e2e22aa0315
Date: Avant le dernier déploiement Mapbox (2 commits avant a0e0d11)

## Structure FileType HomeMapPage

### État des variables (initState)
```dart
_MapAction _selected = _MapAction.ville;  // Action sélectionnée au démarrage
bool _showActionsMenu = false;             // Menu burger fermé par défaut
LatLng? _userPos;                          // Position GPS initiale: null
bool _followUser = true;                   // Suit l'utilisateur au démarrage
bool _isTracking = false;                  // GPS tracking désactivé
bool _isMapReady = false;                  // Carte non prête au démarrage
bool _isGpsReady = false;                  // GPS non prêt au démarrage
```

### Enum MapAction (5 actions principales)
```dart
enum _MapAction { 
  ville,          // 🏘️ Vue générale (défaut)
  tracking,       // 📍 GPS Tracking groupes
  visiter,        // 🗺️ Lieux touristiques
  encadrement,    // 🛡️ Points d'encadrement
  food,           // 🍔 Restaurants
  wc,             // 🚻 Toilettes
  parking         // 🅿️ Parkings
}
```

### Services utilisés
- `FirestoreService`: Récupère les circuits et lieux
- `GeolocationService`: Gestion du GPS et tracking
- `MapPresetsService`: Gestion des cartes pré-enregistrées
- `MapboxTokenService`: Configuration du token Mapbox
- `AuthService`: Authentification et permissions

### Intégrations Mapbox
```dart
const _mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
const _legacyMapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

bool get _useMapboxTiles => _effectiveMapboxToken.isNotEmpty;
bool get _useMapboxGlWeb => kIsWeb && _effectiveMapboxToken.trim().isNotEmpty;
```

### Comportement par action
**VILLE (défaut)**
- Centre: 16.241, -61.533
- Zoom: 12.5 (sans GPS) ou 14.5 (avec GPS)
- Affiche: Tuiles Mapbox ou OpenStreetMap
- Marqueurs: Lieux vides (selon filtre)

**TRACKING**
- Affiche: Polylines circuits (noir 65% opacité)
- Marqueurs: Positions groupes en temps réel
- Refresh: Via Firestore snapshots
- Filtre: Positions < 3min d'âge

**VISITER**
- Stream: PlaceType.visit
- Icônes: Colorées par type
- Sheet: Détails sur tap

**FOOD**
- Stream: PlaceType.food
- Couleur: Couleur spécifique alimentation

**ENCADREMENT**
- Stream: PlaceType.market
- Couleur: Couleur spécifique encadrement

**WC**
- Stream: PlaceType.wc
- Petit marqueur: Position

**PARKING**
- Stream: PlaceType.parking
- Couleur: Bleu (0xFF0D97EB)

### Menu d'actions (SlideTransition)
Visible après tap du 🍔 burger (haut droite):
- 🗺️ Cartes (superadmin seulement)
- 📍 Centrer sur utilisateur
- 📍 Tracking GPS
- 🗺️ Visiter
- 🍔 Food
- 🛡️ Encadrement
- 🅿️ Parking
- 🚻 WC

### Contrôles au démarrage
✅ Token Mapbox: String.fromEnvironment('MAPBOX_ACCESS_TOKEN')
✅ GPS: GeolocationService.instance
✅ Authentification: FirebaseAuth
✅ Suivi: StreamSubscription<Position>

### Couches de la carte (FlutterMap)
1. TileLayer (Mapbox ou OpenStreetMap)
2. Attribution (© Mapbox, © OSM)
3. MarkerLayer: Position utilisateur
4. StreamBuilder: Marqueurs lieux
5. PolylineLayer: Circuits (si tracking)
6. MarkerLayer: Groupes (si tracking)

### Position UI
✅ Carte: Positioned.fill (plein écran)
✅ Menu burger: En haut à droite
✅ Bottom bar: Profil utilisateur + navigation
✅ Overlay menu: SlideTransition depuis droite
✅ Quick layers panel: Bas gauche (si preset chargé)
✅ GPS tracking pill: Bas gauche (si tracking actif)

## Configuration Mapbox au commit 0b19da0
- ✅ MapboxWebView utilisée sur Web
- ✅ FlutterMap utilisée sur mobile/desktop
- ✅ Token fallback: buildEnvironment puis runtime
- ✅ Style: mapbox://styles/mapbox/streets-v12
- ✅ Zoom par défaut: 12.5 (général) ou 15.0 (Web avec GPS)
