# Structure Firestore : map_projects (Mapbox-only)

## 📋 Vue d'ensemble

Collection principale pour stocker les projets cartographiques Mapbox de l'application MASLIVE.

**Chemin Firestore :** `map_projects/{projectId}`

---

## 🗂️ Schéma des documents

### Collection principale : `map_projects`

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `id` | `string` | ✅ | ID du document (auto-généré ou custom) |
| `countryId` | `string` | ✅ | Identifiant du pays (ex: "GP", "MQ", "FR") |
| `eventId` | `string` | ✅ | Identifiant de l'événement associé |
| `name` | `string` | ✅ | Nom du projet cartographique |
| `status` | `string` | ✅ | État du projet : `"draft"` \| `"ready"` \| `"published"` |
| `isVisible` | `boolean` | ✅ | Visibilité publique du projet |
| `publishAt` | `Timestamp` | ❌ | Date de publication planifiée (optionnel) |
| `publishedAt` | `Timestamp` | ❌ | Date de publication effective |
| `styleUrl` | `string` | ✅ | URL du style Mapbox (ex: `mapbox://styles/mapbox/streets-v12`) |
| `perimeter` | `Array<Object>` | ✅ | Polygone délimitant la zone (array de `{lng, lat}`) |
| `route` | `Array<Object>` | ✅ | Trajet/itinéraire (array de `{lng, lat}`) |
| `createdAt` | `Timestamp` | ✅ | Date de création |
| `updatedAt` | `Timestamp` | ✅ | Date de dernière modification |
| `ownerUid` | `string` | ✅ | UID Firebase du propriétaire |
| `editors` | `Array<string>` | ✅ | Liste des UIDs ayant droit d'édition |

### Sous-collection : `map_projects/{projectId}/layers`

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `id` | `string` | ✅ | ID du layer (auto-généré) |
| `type` | `string` | ✅ | Type de layer : `"tracking"` \| `"visited"` \| `"full"` \| `"assistance"` \| `"parking"` \| `"wc"` |
| `label` | `string` | ✅ | Libellé affiché dans l'interface |
| `iconKey` | `string` | ✅ | Clé de l'icône (ex: "location_on", "local_parking", "wc") |
| `isVisibleByDefault` | `boolean` | ✅ | Visibilité par défaut à l'ouverture de la carte |
| `isEditable` | `boolean` | ✅ | Autorise l'édition des points de ce layer |
| `zIndex` | `number` | ✅ | Ordre d'affichage (valeurs plus élevées = au-dessus) |

### Sous-sous-collection : `map_projects/{projectId}/layers/{layerId}/points`

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `id` | `string` | ✅ | ID du point (auto-généré) |
| `lng` | `number` | ✅ | Longitude (coordonnée géographique) |
| `lat` | `number` | ✅ | Latitude (coordonnée géographique) |
| `title` | `string` | ✅ | Titre du point (ex: "Parking Central", "Poste de secours #1") |
| `description` | `string` | ❌ | Description détaillée (optionnel) |
| `createdAt` | `Timestamp` | ✅ | Date de création |
| `updatedAt` | `Timestamp` | ✅ | Date de dernière modification |

---

## 📐 Structure détaillée des champs

### `status`
```typescript
type ProjectStatus = "draft" | "ready" | "published";
```

**Flux de publication :**
- `draft` : Projet en cours de création/modification
- `ready` : Projet finalisé, prêt à être publié
- `published` : Projet visible publiquement

### `perimeter` (Polygon)
```typescript
type Coordinate = { lng: number; lat: number };
type Perimeter = Coordinate[];
```

**Format :**
```json
[
  { "lng": -61.5340, "lat": 16.2410 },
  { "lng": -61.5250, "lat": 16.2350 },
  { "lng": -61.5300, "lat": 16.2300 },
  { "lng": -61.5340, "lat": 16.2410 }
]
```

**Notes :**
- Premier et dernier point identiques pour fermer le polygone
- Sens horaire ou antihoraire selon convention Mapbox
- Utilisé pour délimiter une zone géographique (pays, région, circuit)

### `route` (Polyline)
```typescript
type Route = Coordinate[];
```

**Format :**
```json
[
  { "lng": -61.5340, "lat": 16.2410 },
  { "lng": -61.5320, "lat": 16.2380 },
  { "lng": -61.5300, "lat": 16.2350 },
  { "lng": -61.5280, "lat": 16.2320 }
]
```

**Notes :**
- Points ordonnés selon le parcours
- Peut être généré via OSRM ou dessiné manuellement
- Utilisé pour afficher un itinéraire sur la carte

### `styleUrl`
```typescript
type StyleUrl = string; // Format: mapbox://styles/{username}/{style_id}
```

**Exemples standards Mapbox :**
```
mapbox://styles/mapbox/streets-v12
mapbox://styles/mapbox/outdoors-v12
mapbox://styles/mapbox/light-v11
mapbox://styles/mapbox/dark-v11
mapbox://styles/mapbox/satellite-v9
mapbox://styles/mapbox/satellite-streets-v12
mapbox://styles/mapbox/navigation-day-v1
mapbox://styles/mapbox/navigation-night-v1
```

**Style custom :**
```
mapbox://styles/your-username/custom-style-id
```

### `type` (Layer)
```typescript
type LayerType = 
  | "tracking"     // Points de suivi en temps réel
  | "visited"      // Points déjà visités
  | "full"         // Tous les points (tracking + visited)
  | "assistance"   // Points d'assistance/secours
  | "parking"      // Parkings
  | "wc";          // Toilettes publiques
```

**Utilisation :**
- `tracking` : Affiche uniquement les positions actives en temps réel
- `visited` : Historique des passages (grisé/transparent)
- `full` : Combine tracking + visited
- `assistance` : Points fixes d'aide (secouristes, infirmerie)
- `parking` : Zones de stationnement
- `wc` : Sanitaires publics

### `iconKey`
```typescript
type IconKey = string; // Nom d'icône Material Icons ou custom
```

**Exemples Material Icons :**
```
"location_on"       // Pin de localisation
"directions_walk"   // Marche
"local_parking"     // Parking
"wc"                // Toilettes
"local_hospital"    // Assistance médicale
"info"              // Information
"restaurant"        // Restauration
"flag"              // Drapeau (départ/arrivée)
```

### `zIndex`
```typescript
type ZIndex = number; // 0 = arrière-plan, 999 = premier plan
```

**Convention recommandée :**
```
0-99    : Layers de fond (zones, périmètres)
100-199 : Historique/visited
200-299 : Points fixes (parkings, WC, assistance)
300-399 : Tracking temps réel
400-499 : Markers utilisateur
500+    : Overlays temporaires
```

---

## 💾 Exemple de document complet

```json
{
  "id": "gp-carnaval-2026",
  "countryId": "GP",
  "eventId": "carnaval-2026",
  "name": "Circuit Carnaval Guadeloupe 2026",
  "status": "published",
  "isVisible": true,
  "publishAt": null,
  "publishedAt": {
    "_seconds": 1738368000,
    "_nanoseconds": 0
  },
  "styleUrl": "mapbox://styles/mapbox/streets-v12",
  "perimeter": [
    { "lng": -61.5340, "lat": 16.2410 },
    { "lng": -61.5250, "lat": 16.2450 },
    { "lng": -61.5200, "lat": 16.2380 },
    { "lng": -61.5260, "lat": 16.2320 },
    { "lng": -61.5340, "lat": 16.2410 }
  ],
  "route": [
    { "lng": -61.5340, "lat": 16.2410 },
    { "lng": -61.5320, "lat": 16.2390 },
    { "lng": -61.5300, "lat": 16.2370 },
    { "lng": -61.5280, "lat": 16.2350 },
    { "lng": -61.5260, "lat": 16.2330 }
  ],
  "createdAt": {
    "_seconds": 1738281600,
    "_nanoseconds": 0
  },
  "updatedAt": {
    "_seconds": 1738368000,
    "_nanoseconds": 0
  },
  "ownerUid": "abc123xyz456",
  "editors": ["abc123xyz456", "def789uvw012"]
}
```

### Exemple de layer (sous-collection)

**Document :** `map_projects/gp-carnaval-2026/layers/tracking-live`

```json
{
  "id": "tracking-live",
  "type": "tracking",
  "label": "Suivi en direct",
  "iconKey": "location_on",
  "isVisibleByDefault": true,
  "isEditable": false,
  "zIndex": 300
}
```

**Document :** `map_projects/gp-carnaval-2026/layers/parkings-publics`

```json
{
  "id": "parkings-publics",
  "type": "parking",
  "label": "Parkings disponibles",
  "iconKey": "local_parking",
  "isVisibleByDefault": true,
  "isEditable": true,
  "zIndex": 250
}
```

**Document :** `map_projects/gp-carnaval-2026/layers/points-assistance`

```json
{
  "id": "points-assistance",
  "type": "assistance",
  "label": "Postes de secours",
  "iconKey": "local_hospital",
  "isVisibleByDefault": true,
  "isEditable": true,
  "zIndex": 280
}
```

### Exemple de point (sous-sous-collection)

**Document :** `map_projects/gp-carnaval-2026/layers/parkings-publics/points/parking-mairie`

```json
{
  "id": "parking-mairie",
  "lng": -61.5340,
  "lat": 16.2410,
  "title": "Parking Mairie de Pointe-à-Pitre",
  "description": "250 places - Gratuit pendant l'événement",
  "createdAt": {
    "_seconds": 1738281600,
    "_nanoseconds": 0
  },
  "updatedAt": {
    "_seconds": 1738281600,
    "_nanoseconds": 0
  }
}
```

**Document :** `map_projects/gp-carnaval-2026/layers/points-assistance/points/secours-01`

```json
{
  "id": "secours-01",
  "lng": -61.5320,
  "lat": 16.2390,
  "title": "Poste de secours principal",
  "description": "Secouristes + infirmiers - Ouvert 24h/24",
  "createdAt": {
    "_seconds": 1738281600,
    "_nanoseconds": 0
  },
  "updatedAt": {
    "_seconds": 1738281600,
    "_nanoseconds": 0
  }
}
```

**Document :** `map_projects/gp-carnaval-2026/layers/wc-publics/points/wc-centre`

```json
{
  "id": "wc-centre",
  "lng": -61.5300,
  "lat": 16.2370,
  "title": "Toilettes Centre-ville",
  "description": null,
  "createdAt": {
    "_seconds": 1738281600,
    "_nanoseconds": 0
  },
  "updatedAt": {
    "_seconds": 1738281600,
    "_nanoseconds": 0
  }
}
```

---

## 🔍 Queries Firestore recommandées

### 1. Récupérer tous les projets publiés d'un pays
```dart
final query = firestore
  .collection('map_projects')
  .where('countryId', isEqualTo: 'GP')
  .where('status', isEqualTo: 'published')
  .where('isVisible', isEqualTo: true)
  .orderBy('publishedAt', descending: true);
```

### 2. Récupérer les projets d'un événement
```dart
final query = firestore
  .collection('map_projects')
  .where('eventId', isEqualTo: 'carnaval-2026')
  .orderBy('createdAt', descending: true);
```

### 3. Récupérer les projets modifiables par un utilisateur
```dart
final query = firestore
  .collection('map_projects')
  .where('editors', arrayContains: currentUserUid);
```

### 4. Récupérer les projets créés par un utilisateur
```dart
final query = firestore
  .collection('map_projects')
  .where('ownerUid', isEqualTo: currentUserUid)
  .orderBy('updatedAt', descending: true);
```

### 7. Récupérer uniquement les layers visibles par défaut
```dart
final visibleLayersQuery = firestore
  .collection('map_projects')
  .doc(projectId)
  .collection('layers')
  .where('isVisibleByDefault', isEqualTo: true)
  .orderBy('zIndex', descending: false);
```

### 8. Récupérer les layers éditables d'un type spécifique
```dart
final now = Timestamp.now();
final query = firestore
  .collection('map_projects')
  .where('status', isEqualTo: 'ready')
  .where('publishAt', isLessThanOrEqualTo: now)
  .where('publishAt', isNotEqualTo: null);
```

---

## 🔐 Règles de sécurité Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(projectData) {
      return isAuthenticated() && 
             request.auth.uid == projectData.ownerUid;
    }
    
    function isEditor(projectData) {
      return isAuthenticated() && 
             (request.auth.uid in projectData.editors || 
              isOwner(projectData));
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid))
               .data.role in ['admin', 'superAdmin'];
    }
    
    // map_projects collection
    match /map_projects/{projectId} {
      
      // Lecture : projets publiés visibles par tous, autres par owners/editors/admins
      allow read: if resource.data.status == 'published' && 
                     resource.data.isVisible == true ||
                     isEditor(resource.data) ||
                     isAdmin();
      
      // Création : utilisateurs authentifiés (ownerUid = auth.uid obligatoire)
      allow create: if isAuthenticated() && 
                       request.resource.data.ownerUid == request.auth.uid &&
                       request.resource.data.editors is list &&
                       request.auth.uid in request.resource.data.editors;
      
      // Modification : owner, editors ou admin
      allow update: if isEditor(resource.data) || isAdmin();
      
      // Suppression : owner ou admin uniquement
      allow delete: if isOwner(resource.data) || isAdmin();
    }
    
    // Sous-collection layers
    match /map_projects/{projectId}/layers/{layerId} {
      
      // Lecture : même règle que le projet parent
      allow read: if get(/databases/$(database)/documents/map_projects/$(projectId))
                       .data.status == 'published' &&
                     get(/databases/$(database)/documents/map_projects/$(projectId))
                       .data.isVisible == true ||
                     isEditor(get(/databases/$(database)/documents/map_projects/$(projectId)).data) ||
                     isAdmin();
      
      // Création/Modification : editors du projet parent ou admin
      allow create, update: if isEditor(get(/databases/$(database)/documents/map_projects/$(projectId)).data) ||
                               isAdmin();
      
      // Suppression : owner du projet parent ou admin
      allow delete: if isOwner(get(/databases/$(database)/documents/map_projects/$(projectId)).data) ||
                       isAdmin();
    }
    
    // Sous-sous-collection points
    match /map_projects/{projectId}/layers/{layerId}/points/{pointId} {
      
      // Lecture : même règle que le projet parent
      allow read: if get(/databases/$(database)/documents/map_projects/$(projectId))
                       .data.status == 'published' &&
                     get(/databases/$(database)/documents/map_projects/$(projectId))
                       .data.isVisible == true ||
                     isEditor(get(/databases/$(database)/documents/map_projects/$(projectId)).data) ||
                     isAdmin();
      
      // Création/Modification : editors du projet parent ou admin
      // + vérification que le layer parent est éditable
      allow create, update: if (isEditor(get(/databases/$(database)/documents/map_projects/$(projectId)).data) ||
                                isAdmin()) &&
                               get(/databases/$(database)/documents/map_projects/$(projectId)/layers/$(layerId))
                                 .data.isEditable == true;
      
      // Suppression : editors du projet parent ou admin (si layer éditable)
      allow delete: if (isEditor(get(/databases/$(database)/documents/map_projects/$(projectId)).data) ||
                        isAdmin()) &&
                       get(/databases/$(database)/documents/map_projects/$(projectId)/layers/$(layerId))
                         .data.isEditable == true;
    }
  }
}
```

---

## 📊 Index Firestore requis

Pour optimiser les queries, créez les index composites suivants dans Firestore :

### Index 1 : Projets publiés par pays
```
Collection: map_projects
Fields:
  - countryId (Ascending)
  - status (Ascending)
  - isVisible (Ascending)
  - publishedAt (Descending)
```

### Index 2 : Projets par événement
```
Collection: map_projects
Fields:
  - eventId (Ascending)
  - createdAt (Descending)
```

### Index 3 : Projets éditables avec date
```
Collection: map_projects
Fields:
  - editors (Array)
  - updatedAt (Descending)
```

### Index 4 : Publication automatique
```
Collection: map_projects
Fields:
  - status (Ascending)
  - publishAt (Ascending)
```

### Index 5 : Layers visibles par défaut
```
Collection: map_projects/{projectId}/layers
Fields:
  - isVisibleByDefault (Ascending)
  - zIndex (Ascending)
```

### Index 6 : Layers par type et éditabilité
```
Collection: map_projects/{projectId}/layers
Fields:
  - type (Ascending)
  - isEditable (Ascending)
```

### Index 7 : Points par date de création
```
Collection: map_projects/{projectId}/layers/{layerId}/points
Fields:
  - createdAt (Descending)
```

**Création automatique :** Firebase proposera de créer ces index lors de la première query qui en a besoin.

**Note sur les geo-queries :** Pour des recherches géographiques efficaces (proximité, bounding box), envisagez d'utiliser [GeoFlutterFire](https://pub.dev/packages/geoflutterfire) ou stocker des geohashes.

---

## 🎯 Cas d'usage

### 1. Créer un nouveau projet
```dart
final projectRef = firestore.collection('map_projects').doc();
await projectRef.set({
  'countryId': 'GP',
  'eventId': 'carnaval-2026',
  'name': 'Circuit Principal',
  'status': 'draft',
  'isVisible': false,
  'publishAt': null,
  'publishedAt': null,
  'styleUrl': 'mapbox://styles/mapbox/streets-v12',
  'perimeter': [],
  'route': [],
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  'ownerUid': currentUser.uid,
  'editors': [currentUser.uid],
});
```

### 2. Publier un projet
```dart
await projectRef.update({
  'status': 'published',
  'isVisible': true,
  'publishedAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### 3. Planifier une publication
```dart
final publishDate = DateTime(2026, 2, 15, 10, 0); // 15 fév 2026, 10h
await projectRef.update({
  'status': 'ready',
  'publishAt': Timestamp.fromDate(publishDate),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### 4. Ajouter un éditeur
```dart
await projectRef.update({
  'editors': FieldValue.arrayUnion([newEditorUid]),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### 5. Mettre à jour le tracé
```dart
await projectRef.update({
  'route': newRouteCoordinates,
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### 6. Créer des layers pour un projet
```dart
final projectRef = firestore.collection('map_projects').doc(projectId);

// Layer tracking live
await projectRef.collection('layers').doc('tracking-live').set({
  'type': 'tracking',
  'label': 'Suivi en direct',
  'iconKey': 'location_on',
  'isVisibleByDefault': true,
  'isEditable': false,
  'zIndex': 300,
});

// Layer parkings
await projectRef.collection('layers').doc('parkings').set({
  'type': 'parking',
  'label': 'Parkings',
  'iconKey': 'local_parking',
  'isVisibleByDefault': true,
  'isEditable': true,
  'zIndex': 250,
});

// Layer assistance
await projectRef.collection('layers').doc('assistance').set({
  'type': 'assistance',
  'label': 'Postes de secours',
  'iconKey': 'local_hospital',
  'isVisibleByDefault': true,
  'isEditable': true,
  'zIndex': 280,
});
```

### 7. Charger les layers et afficher selon visibilité
```dart
final layersSnapshot = await projectRef
  .collection('layers')
  .orderBy('zIndex')
  .get();

for (final doc in layersSnapshot.docs) {
  final layer = doc.data();
  if (layer['isVisibleByDefault'] == true) {
    // Afficher ce layer sur la carte
    print('Afficher layer: ${layer['label']} (zIndex: ${layer['zIndex']})');
  }
}
```

### 8. Ajouter des points à un layer
```dart
final layerRef = projectRef.collection('layers').doc(layerId);

// Point de parking
await layerRef.collection('points').add({
  'lng': -61.5340,
  'lat': 16.2410,
  'title': 'Parking Mairie',
  'description': '250 places - Gratuit',
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});

// Point d'assistance
await layerRef.collection('points').add({
  'lng': -61.5320,
  'lat': 16.2390,
  'title': 'Poste de secours #1',
  'description': 'Secouristes + infirmiers disponibles',
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### 9. Mettre à jour un point existant
```dart
await layerRef.collection('points').doc(pointId).update({
  'title': 'Parking Mairie (Complet)',
  'description': '250 places - COMPLET',
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### 10. Supprimer un point
```dart
await layerRef.collection('points').doc(pointId).delete();
```

---

## 🔄 Intégration avec MasLiveMap

### Afficher un projet sur la carte

```dart
final project = await firestore
  .collection('map_projects')
  .doc(projectId)
  .get();

final data = project.data()!;

// Afficher le périmètre (polygon)
await mapController.setPolygon(
  data['perimeter']
    .map((coord) => MapPoint(lng: coord['lng'], lat: coord['lat']))
    .toList(),
  fillColor: Colors.blue.withOpacity(0.2),
  strokeColor: Colors.blue,
  strokeWidth: 2.0,
);

// Afficher le tracé (polyline)
await mapController.setPolyline(
  data['route']
    .map((coord) => MapPoint(lng: coord['lng'], lat: coord['lat']))
    .toList(),
  color: Colors.red,
  width: 3.0,
);

// Centrer sur le périmètre
if (data['perimeter'].isNotEmpty) {
  final firstPoint = data['perimeter'][0];
  await mapController.moveTo(
    lng: firstPoint['lng'],
    lat: firstPoint['lat'],
    zoom: 13.0,
  );
}

// Gérer les layers avec zIndex
final layersSnapshot = await projectRef
  .collection('layers')
  .orderBy('zIndex')
  .get();

for (final layerDoc in layersSnapshot.docs) {
  final layer = layerDoc.data();
  
  if (!layer['isVisibleByDefault']) continue;
  
  switch (layer['type']) {
    case 'tracking':
      // Afficher markers en temps réel (source externe: groupLocations)
      final trackingSnapshot = await firestore
        .collection('groupLocations')
        .get();
      // ... afficher avec mapController.setMarkers()
      break;
      
    case 'parking':
    case 'wc':
    case 'assistance':
      // Charger les points statiques depuis la sous-collection
      final pointsSnapshot = await projectRef
        .collection('layers')
        .doc(layerDoc.id)
        .collection('points')
        .get();
      
      final markers = pointsSnapshot.docs.map((pointDoc) {
        final point = pointDoc.data();
        return MapMarker(
          id: pointDoc.id,
          lng: point['lng'],
          lat: point['lat'],
          label: point['title'],
          // Couleur selon le type de layer
          color: layer['type'] == 'parking' 
              ? Colors.blue
              : layer['type'] == 'assistance'
                  ? Colors.red
                  : Colors.orange,
        );
      }).toList();
      
      await mapController.setMarkers(markers);
      break;
  }
}

// Exemple complet: afficher tous les layers avec leurs points
Future<void> displayProjectWithLayers(String projectId) async {
  final projectRef = firestore.collection('map_projects').doc(projectId);
  final projectSnapshot = await projectRef.get();
  final projectData = projectSnapshot.data()!;
  
  // 1. Afficher le périmètre
  await mapController.setPolygon(
    (projectData['perimeter'] as List).map((c) => 
      MapPoint(lng: c['lng'], lat: c['lat'])
    ).toList(),
  );
  
  // 2. Afficher le tracé
  await mapController.setPolyline(
    (projectData['route'] as List).map((c) => 
      MapPoint(lng: c['lng'], lat: c['lat'])
    ).toList(),
  );
  
  // 3. Charger et afficher tous les layers visibles avec leurs points
  final layersSnapshot = await projectRef
    .collection('layers')
    .where('isVisibleByDefault', isEqualTo: true)
    .orderBy('zIndex')
    .get();
  
  final allMarkers = <MapMarker>[];
  
  for (final layerDoc in layersSnapshot.docs) {
    final layer = layerDoc.data();
    
    // Charger les points du layer
    final pointsSnapshot = await projectRef
      .collection('layers')
      .doc(layerDoc.id)
      .collection('points')
      .get();
    
    for (final pointDoc in pointsSnapshot.docs) {
      final point = pointDoc.data();
      allMarkers.add(MapMarker(
        id: '${layerDoc.id}_${pointDoc.id}',
        lng: point['lng'],
        lat: point['lat'],
        label: point['title'],
        color: _getColorForLayerType(layer['type']),
      ));
    }
  }
  
  // Afficher tous les markers en une fois
  await mapController.setMarkers(allMarkers);
}

Color _getColorForLayerType(String type) {
  switch (type) {
    case 'tracking': return Colors.green;
    case 'parking': return Colors.blue;
    case 'wc': return Colors.orange;
    case 'assistance': return Colors.red;
    default: return Colors.grey;
  }
}
```

---

## 🚀 Prochaines étapes

1. **Créer les modèles Dart** : 
   - `lib/models/map_project.dart`
   - `lib/models/map_layer.dart`
   - `lib/models/map_point.dart` (ou réutiliser `MapMarker` existant)
2. **Service Firestore** : 
   - `lib/services/map_project_service.dart`
   - `lib/services/map_layer_service.dart`
3. **Page admin CRUD** : `lib/admin/admin_map_projects_page.dart`
4. **Éditeur cartographique** : 
   - `lib/admin/map_project_editor_page.dart`
   - Panneau de gestion des layers (toggle visibilité, réordonner zIndex)
5. **Visualisation publique** : `lib/pages/map_project_viewer_page.dart`
6. **Cloud Function** : Auto-publication des projets planifiés (cron)
7. **Points par layer** : Sous-collection `layers/{layerId}/points` pour stocker les markers de chaque layer

---

## 📝 Notes

- **Migration depuis anciens circuits** : Si des données existent dans `circuits` ou `routes`, créer un script de migration
- **Validation côté client** : Vérifier que perimeter est fermé (premier = dernier point)
- **Performance** : Pour de grandes routes (>1000 points), envisager une simplification via algorithme Douglas-Peucker
- **Backup** : Exporter régulièrement les projets publiés en JSON
- **Versioning** : Pour historiser les modifications, créer une sous-collection `map_projects/{id}/history`
- **Layers dynamiques** : Pour les layers de type `tracking`, lier à une collection externe (ex: `groupLocations`) plutôt que stocker les points
- **Icons custom** : Si `iconKey` ne correspond pas à Material Icons, charger depuis Firebase Storage (`icons/{iconKey}.png`)
- **zIndex management** : Dans l'éditeur, prévoir drag-and-drop pour réorganiser l'ordre des layers
- **Filtres layers** : Permettre aux utilisateurs publics de toggler la visibilité de chaque layer
- **Geo-queries optimisées** : Pour des milliers de points, utiliser GeoFlutterFire ou geohashing pour les recherches par proximité
- **Édition collaborative** : Points éditables uniquement si `layer.isEditable == true` (vérifié dans les règles Firestore)
- **Description riche** : Le champ `description` peut contenir du markdown ou HTML pour affichage enrichi dans les popups
- **Clustering** : Pour de nombreux points proches, implémenter un système de clustering côté client avant affichage
- **Cache local** : Stocker les points des layers publiés en cache (SharedPreferences/SQLite) pour mode hors ligne
- **Sous-collection points** : `layers/{layerId}/points/{pointId}` pour stocker les markers statiques (parkings, WC, assistance)

---

**Version :** 1.0  
**Date :** 1er février 2026  
**Auteur :** GitHub Copilot (Phase 2 Migration Mapbox)
