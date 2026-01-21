# Système de Cartes Pré-Enregistrées (Map Presets)

## Vue d'ensemble

Le système de cartes pré-enregistrées permet aux administrateurs de créer, stocker et gérer des cartes personnalisées avec des couches (circuits, POIs, routes, etc.) stockées dans Firestore. Les utilisateurs peuvent ensuite sélectionner facilement une carte et ses couches visibles.

## Architecture

### Modèles de données

#### `MapPresetModel`
Représente une carte pré-enregistrée complète.

**Propriétés:**
- `id`: Identifiant unique (généré par Firestore)
- `title`: Titre de la carte (ex: "Parcours en vélo")
- `description`: Description courte
- `center`: Position centrale (LatLng)
- `zoom`: Niveau de zoom initial
- `layers`: Liste des couches
- `imageUrl`: URL optionnelle pour la vignette
- `groupId`: Groupe associé (pour les permissions)
- `createdAt`, `updatedAt`: Timestamps
- `isPublic`: Visibilité publique

#### `LayerModel`
Représente une couche au sein d'une carte.

**Propriétés:**
- `id`: Identifiant unique
- `name`: Nom de la couche
- `description`: Description
- `type`: Type de couche (`circuits`, `pois`, `routes`, `geofence`, etc.)
- `visible`: État de visibilité par défaut
- `color`: Couleur optionnelle (hex)
- `iconName`: Nom optionnel de l'icône
- `metadata`: Données supplémentaires (JSON)

### Services

#### `MapPresetsService`
Gère toutes les opérations CRUD pour les cartes pré-enregistrées.

**Méthodes principales:**
```dart
// Récupération
Stream<List<MapPresetModel>> getGroupPresetsStream(String groupId)
Stream<List<MapPresetModel>> getPublicPresetsStream(String groupId)
Future<MapPresetModel?> getPreset(String presetId)

// Création/Modification
Future<String> createPreset(MapPresetModel preset)
Future<void> updatePreset(MapPresetModel preset)
Future<void> updateLayerVisibility(String presetId, String layerId, bool visible)
Future<void> addLayer(String presetId, LayerModel layer)
Future<void> removeLayer(String presetId, String layerId)

// Suppression
Future<void> deletePreset(String presetId)
Future<String> duplicatePreset(MapPresetModel preset)
```

### Pages

#### `MapSelectorPage`
Interface utilisateur pour sélectionner une carte et ses couches.

**Fonctionnalités:**
- Affiche la liste des cartes du groupe
- Permet de sélectionner une carte
- Affiche et permet de toggler les couches
- Badge affichant le nombre de couches
- Animation d'expansion pour les couches
- Bouton "Appliquer" pour confirmer la sélection

**Utilisation:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MapSelectorPage(
      groupId: 'group123',
      initialPreset: currentPreset,
      onMapSelected: (preset, visibleLayers) {
        // Carte sélectionnée
        _mapController.move(preset.center, preset.zoom);
      },
    ),
  ),
);
```

### Intégration dans HomeMapPage

**Bouton "Cartes" dans le menu:**
- Accessible depuis le menu d'actions (burger menu)
- Icône: `Icons.layers_rounded`
- Ouvre `MapSelectorPage`
- Sélectionne automatiquement le groupe de l'utilisateur
- Centre la carte et affiche les couches choisies

**Utilisation de la carte sélectionnée:**
```dart
_selectedPreset       // MapPresetModel actuellement choisie
_userGroupId          // ID du groupe de l'utilisateur
```

## Structure Firestore

```
map_presets/
├── <docId>
│   ├── title: string
│   ├── description: string
│   ├── center: { latitude: double, longitude: double }
│   ├── zoom: double
│   ├── layers: [
│   │   {
│   │     id: string,
│   │     name: string,
│   │     description: string,
│   │     type: string,
│   │     visible: boolean,
│   │     color: string?,
│   │     iconName: string?,
│   │     metadata: object
│   │   }
│   ├── imageUrl: string?
│   ├── groupId: string
│   ├── createdAt: timestamp
│   ├── updatedAt: timestamp
│   └── isPublic: boolean
```

## Cas d'usage

### 1. Administrateur crée une carte
```dart
final preset = MapPresetModel(
  id: '', // Sera générés par Firestore
  title: 'Itinéraire Carnaval 2025',
  description: 'Circuit principal du carnaval',
  center: const LatLng(14.6091, -61.0823),
  zoom: 12.5,
  layers: [
    LayerModel(
      id: 'layer_circuits',
      name: 'Circuits',
      type: 'circuits',
      visible: true,
    ),
    LayerModel(
      id: 'layer_pois',
      name: 'Points d\'intérêt',
      type: 'pois',
      visible: true,
    ),
  ],
  groupId: 'guadeloupe_carnival_2025',
);

await MapPresetsService().createPreset(preset);
```

### 2. Utilisateur sélectionne une carte
- Ouvre le menu (burger)
- Clique sur "Cartes"
- Sélectionne une carte
- Toggle les couches visibles
- Clique "Appliquer"
- La carte se centre et affiche les couches

### 3. Modification d'une couche
```dart
final preset = await service.getPreset('preset123');
if (preset != null) {
  final layer = preset.getLayer('layer_circuits');
  if (layer != null) {
    final updatedLayer = layer.copyWith(visible: false);
    final updatedPreset = preset.withLayer(updatedLayer);
    await service.updatePreset(updatedPreset);
  }
}
```

## Points clés d'implémentation

### Sélection facile
- Interface intuitive avec boutons radio et checkboxes
- Expansion/collapse des couches pour économiser l'espace
- Badges visuels indiquant le nombre de couches
- Feedback visuel immédiat

### Intégration HomeMapPage
- Le bouton "Cartes" apparaît dans le menu d'actions
- Récupère automatiquement le groupId de l'utilisateur
- Centre la carte sur la position stockée
- Affiche un snackbar de confirmation

### Système de couches flexible
- Support de multiples types de couches
- Metadata extensible pour options personnalisées
- Visibilité configurable par couche
- Couleurs et icônes optionnelles

## Améliorations futures possibles

1. **Éditeur de cartes**: Créer/modifier directement depuis l'app
2. **Partage de cartes**: Entre utilisateurs ou groupes
3. **Cartes favoris**: Sauvegarder les dernières utilisées
4. **Historique**: Revenir à une carte précédente
5. **Modèles**: Templates de cartes pré-créées
6. **Validation**: Vérifier la cohérence des données
7. **Synchronisation**: Sync offline avec Hive
8. **Analytics**: Tracker les cartes les plus utilisées

## Références

- [FirestoreService](../services/firestore_service.dart)
- [MapAdminEditorPage](./map_admin_editor_page.dart)
- [RouteDrawingPage](./route_drawing_page.dart)
