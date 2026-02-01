# MapMarket - Wizard Complet Mapbox-Only

## Vue d'ensemble

Le wizard MapMarket permet aux administrateurs de créer et éditer des projets cartographiques complets avec MasLiveMap (Mapbox-only Web + Mobile).

## Architecture

### Fichiers créés

1. **[map_project_wizard_page.dart](app/lib/admin/map_project_wizard_page.dart)** (600+ lignes)
   - Widget StatefulWidget complet avec 5 étapes
   - Utilise MasLiveMap pour l'édition géographique
   - Sauvegarde automatique dans Firestore

2. **[map_project_wizard_entry_page.dart](app/lib/admin/map_project_wizard_entry_page.dart)** (20 lignes)
   - Point d'entrée qui extrait le `projectId` des arguments de route
   - Instancie MapProjectWizardPage avec le projectId

## Les 5 étapes du Wizard

### Step 0 : Informations de base
**Champs éditables :**
- Nom du projet
- Country ID
- Event ID  
- Style URL (Mapbox)

**Sauvegarde :** Bouton "Sauvegarder" → met à jour Firestore `map_projects/{projectId}`

---

### Step 1 : Périmètre (Polygon)
**Interface :**
- Carte MasLiveMap (400px de hauteur)
- 2 boutons flottants (edit, clear)

**Fonctionnalité :**
1. Clic sur bouton **Edit** (violet) → active le mode édition
2. Mode édition actif → chaque tap sur la carte ajoute un point au périmètre
3. Affichage automatique du polygon dès 3 points :
   - Remplissage : `Color(0x409B6BFF)` (violet semi-transparent)
   - Contour : `Color(0xFF9B6BFF)` (violet opaque, 2px)
4. Compteur : "Points: X"
5. Bouton **Sauvegarder le périmètre** → stocke les points dans `perimeter` field

**Données sauvegardées :**
```json
{
  "perimeter": [
    {"lng": -61.533, "lat": 16.241},
    {"lng": -61.534, "lat": 16.242},
    {"lng": -61.535, "lat": 16.243}
  ]
}
```

---

### Step 2 : Circuit / Route (Polyline)
**Interface :**
- Carte MasLiveMap (400px de hauteur)
- 2 boutons flottants (edit, clear)

**Fonctionnalité :**
1. Clic sur bouton **Edit** (violet) → active le mode édition
2. Mode édition actif → chaque tap sur la carte ajoute un point à la route
3. Affichage automatique de la polyline dès 2 points :
   - Couleur : `Color(0xFFFF7AAE)` (rose)
   - Largeur : 3px
4. Compteur : "Points: X"
5. Bouton **Sauvegarder le circuit** → stocke les points dans `route` field

**Données sauvegardées :**
```json
{
  "route": [
    {"lng": -61.533, "lat": 16.241},
    {"lng": -61.534, "lat": 16.242}
  ]
}
```

---

### Step 3 : Gestion des Layers
**Interface :**
- StreamBuilder connecté à la sous-collection `layers`
- Liste des 6 layers créés automatiquement lors de la création du projet

**Affichage par layer :**
- Icône : basée sur le type (my_location, check_circle, layers, help, local_parking, wc)
- Titre : label du layer
- Sous-titre : type du layer
- Switch : toggle `isVisible`

**Actions :**
- Switch → met à jour `isVisible` en temps réel dans Firestore
- Tap sur un layer → affiche un SnackBar "Edition points: TODO prochaine phase"

**Types de layers :**
| Type        | Icône           | Label par défaut      |
|-------------|-----------------|------------------------|
| tracking    | my_location     | Tracking               |
| visited     | check_circle    | Visités                |
| full        | layers          | Tous les points        |
| assistance  | help            | Assistance             |
| parking     | local_parking   | Parkings               |
| wc          | wc              | WC                     |

---

### Step 4 : Publication
**Interface :**
- StreamBuilder sur le document projet pour afficher le statut en temps réel
- Affichage : "Statut actuel: draft|published|archived"
- SwitchListTile : "Visible publiquement"
- Bouton : **PUBLIER LE PROJET** (violet, grand)

**Action de publication :**
1. Clic sur "PUBLIER LE PROJET"
2. Mise à jour Firestore :
   ```json
   {
     "status": "published",
     "isVisible": true,
     "publishedAt": FieldValue.serverTimestamp(),
     "publishAt": FieldValue.serverTimestamp(),
     "updatedAt": FieldValue.serverTimestamp()
   }
   ```
3. SnackBar : "Projet publié avec succès !"
4. Navigation back vers la liste des projets

---

## Intégration MasLiveMap

### Utilisation du Controller

```dart
final MasLiveMapController _mapController = MasLiveMapController();

// Toggle du mode édition
_mapController.setEditingEnabled(enabled: true);

// Affichage du polygon
_mapController.setPolygon(
  points: [MapPoint(-61.533, 16.241), MapPoint(-61.534, 16.242)],
  fillColor: const Color(0x409B6BFF),
  strokeColor: const Color(0xFF9B6BFF),
  strokeWidth: 2.0,
  show: true,
);

// Affichage de la polyline
_mapController.setPolyline(
  points: [MapPoint(-61.533, 16.241), MapPoint(-61.534, 16.242)],
  color: const Color(0xFFFF7AAE),
  width: 3.0,
  show: true,
);

// Effacer toutes les annotations
_mapController.clearAll();
```

### Callbacks

```dart
MasLiveMap(
  controller: _mapController,
  initialLng: -61.533,
  initialLat: 16.241,
  initialZoom: 12.0,
  onMapReady: (ctrl) {
    // Appelé quand la carte est prête
    // Restaurer les points existants
    _updatePerimeterDisplay();
  },
  onTap: (point) {
    // Appelé lors d'un tap sur la carte
    if (_isEditingPerimeter) {
      _addPerimeterPoint(point.lng, point.lat);
    }
  },
)
```

## Conversion des données

### Map → MapPoint

```dart
// Stockage Firestore (Map)
List<Map<String, double>> _perimeterPoints = [
  {'lng': -61.533, 'lat': 16.241},
  {'lng': -61.534, 'lat': 16.242},
];

// Conversion pour MasLiveMapController
final points = _perimeterPoints
    .map((p) => MapPoint(p['lng']!, p['lat']!))
    .toList();

_mapController.setPolygon(points: points, ...);
```

## Flux utilisateur complet

```
1. Admin crée un projet depuis MapMarketProjectsPage
   ↓
2. Navigation vers /admin/mapmarket/wizard avec {projectId: 'xxx'}
   ↓
3. MapProjectWizardEntryPage extrait projectId
   ↓
4. MapProjectWizardPage charge le projet depuis Firestore
   ↓
5. Step 0 : Edition infos de base → Sauvegarde
   ↓
6. Step 1 : Dessin du périmètre (polygon) → Sauvegarde
   ↓
7. Step 2 : Tracé du circuit (polyline) → Sauvegarde
   ↓
8. Step 3 : Toggle visibility des 6 layers
   ↓
9. Step 4 : Publication → statut "published", isVisible true
   ↓
10. Retour à la liste → Projet visible dans la Home page dropdown
```

## Prochaines phases

### Phase 6 : Edition des points par layer (TODO)
- Page dédiée pour ajouter/éditer les points de chaque layer
- Utilisation de MasLiveMap avec tap-to-add
- Formulaire pour title et description
- Route : `/admin/mapmarket/layer-points` avec arguments :
  ```dart
  {
    'projectId': 'xxx',
    'layerId': 'yyy',
    'layerType': 'tracking',
    'layerLabel': 'Tracking'
  }
  ```

### Phase 7 : Import/Export
- Export JSON des projets
- Import de GPX/KML pour perimeter et route
- Duplication de projets existants

### Phase 8 : Prévisualisation publique
- Route `/map-preview/{projectId}` pour tester avant publication
- Mode read-only avec tous les layers visibles

## Points techniques

### Gestion de l'état
- `_isEditingPerimeter` et `_isEditingRoute` contrôlent le mode édition
- `_currentStep` (0-4) contrôle le Stepper
- Chaque étape peut être réaccédée pour modification

### Sauvegarde
- Chaque étape sauvegarde de manière indépendante
- Aucune validation stricte entre les étapes
- Timestamp `updatedAt` mis à jour à chaque sauvegarde

### Performance
- StreamBuilder pour la mise à jour temps réel des layers
- Pas de polling, juste des écouteurs Firestore
- MasLiveMap gère la performance Web/Mobile de manière optimisée

## Fichiers modifiés

✅ **Nouveau :** [map_project_wizard_page.dart](app/lib/admin/map_project_wizard_page.dart) (600+ lignes)  
✅ **Modifié :** [map_project_wizard_entry_page.dart](app/lib/admin/map_project_wizard_entry_page.dart) (35 → 20 lignes)  
✅ **Lien :** [mapmarket_projects_page.dart](app/lib/admin/mapmarket_projects_page.dart) (navigation vers wizard)  
✅ **Lien :** [main.dart](app/lib/main.dart) (route `/admin/mapmarket/wizard`)

## Coordonnées complètes

- **Admin Dashboard :** [admin_main_dashboard.dart](app/lib/admin/admin_main_dashboard.dart)
- **Listing projets :** [mapmarket_projects_page.dart](app/lib/admin/mapmarket_projects_page.dart)
- **Wizard :** [map_project_wizard_page.dart](app/lib/admin/map_project_wizard_page.dart)
- **Entry point :** [map_project_wizard_entry_page.dart](app/lib/admin/map_project_wizard_entry_page.dart)
- **MasLiveMap :** [maslive_map.dart](app/lib/ui/map/maslive_map.dart)
- **Controller :** [maslive_map_controller.dart](app/lib/ui/map/maslive_map_controller.dart)
- **Schéma Firestore :** [FIRESTORE_MAP_PROJECTS_SCHEMA.md](FIRESTORE_MAP_PROJECTS_SCHEMA.md)
- **Intégration Home :** [MAPMARKET_HOME_INTEGRATION.md](MAPMARKET_HOME_INTEGRATION.md)

## Statut final

✅ **Wizard complet avec 5 étapes opérationnelles**  
✅ **Utilisation de MasLiveMap Mapbox-only (Web + Mobile)**  
✅ **Édition interactive de polygon et polyline**  
✅ **Sauvegarde Firestore automatique**  
✅ **Gestion des 6 layers avec toggle visibility**  
✅ **Publication avec mise à jour du statut**  
✅ **0 erreurs de compilation**  
⏳ **Edition des points par layer** (prochaine phase)
