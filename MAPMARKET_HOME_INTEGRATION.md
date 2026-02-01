# MapMarket - Intégration dans la Home Page

## Vue d'ensemble

Cette intégration permet aux utilisateurs de sélectionner et charger des projets cartographiques publiés directement depuis la page d'accueil (HomeMapPage3D).

## Modifications apportées

### 1. Bouton "Carte" dans la barre d'en-tête

**Fichier**: `app/lib/pages/home_map_page_3d.dart`

Un nouveau bouton a été ajouté dans la barre d'en-tête, juste avant le bouton "Shop":

```dart
MasliveGradientIconButton(
  icon: Icons.map_rounded,
  tooltip: 'Projets cartographiques',
  onTap: _showMapProjectsSelector,
)
```

### 2. État pour le projet sélectionné

Une nouvelle variable d'état a été ajoutée:

```dart
String? _selectedMapProjectId;
```

Cette variable conserve l'ID du projet actuellement sélectionné pour l'affichage dans la liste.

### 3. Méthode `_showMapProjectsSelector()`

Cette méthode affiche un **BottomSheet draggable** contenant:

- **Titre**: "Projets cartographiques"
- **StreamBuilder** connecté à Firestore:
  - Collection: `map_projects`
  - Filtres Firestore:
    - `status == 'published'`
    - `isVisible == true`
    - Tri: `updatedAt` descendant
  - Filtre client (post-query):
    - `publishAt == null` OU `publishAt <= maintenant`

- **Liste des projets**:
  - Icône: carte (violet si sélectionné, gris sinon)
  - Titre: nom du projet (en gras si sélectionné)
  - Sous-titre: `countryId / eventId`
  - Indicateur de sélection: check violet

### 4. Méthode `_loadMapProject(DocumentSnapshot project)`

Appelée lorsqu'un utilisateur sélectionne un projet. Cette méthode:

1. **Charge le style Mapbox personnalisé**:
   ```dart
   await _mapboxMap!.style.setStyleURI(styleUrl);
   ```

2. **Calcule et applique les bounds du périmètre**:
   - Extrait les points du champ `perimeter` (array de `{lng, lat}`)
   - Calcule `minLng`, `maxLng`, `minLat`, `maxLat`
   - Calcule le centre: `(minLng + maxLng) / 2, (minLat + maxLat) / 2`
   - Calcule le zoom approximatif selon la taille du périmètre:
     - `maxDiff > 0.1` → zoom 10
     - `maxDiff > 0.01` → zoom 12
     - Sinon → zoom 14
   - Anime la caméra vers le centre avec `easeTo()` (durée: 1 seconde, pitch: 45°)

## Flux utilisateur

```
1. Utilisateur clique sur l'icône "Carte" (Maps) 🗺️
   ↓
2. BottomSheet s'ouvre avec la liste des projets publiés et visibles
   ↓
3. Utilisateur sélectionne un projet
   ↓
4. Le projet est marqué comme sélectionné (check violet)
   ↓
5. Le BottomSheet se ferme automatiquement
   ↓
6. La carte charge le styleUrl du projet
   ↓
7. La caméra s'anime vers le périmètre du projet (centre + zoom adaptatif)
```

## Critères de publication

Un projet apparaît dans la liste si:

✅ `status == 'published'`  
✅ `isVisible == true`  
✅ `publishAt == null` OU `publishAt <= Timestamp.now()`

## Structure Firestore utilisée

```
map_projects/{projectId}
├── countryId: string
├── eventId: string
├── name: string
├── status: 'draft' | 'published' | 'archived'
├── isVisible: boolean
├── publishAt: Timestamp | null
├── publishedAt: Timestamp | null
├── styleUrl: string (URL du style Mapbox personnalisé)
├── perimeter: Array<{lng: number, lat: number}> (polygon boundary)
├── route: Array<{lng: number, lat: number}> (circuit principal)
├── ownerUid: string
├── editors: Array<string>
├── createdAt: Timestamp
└── updatedAt: Timestamp
```

## Améliorations futures possibles

- [ ] **Chargement des layers**: charger et afficher les sous-collections `layers` et leurs `points`
- [ ] **Toggle de visibilité des layers**: permettre de masquer/afficher chaque layer (tracking, visited, full, assistance, parking, wc)
- [ ] **Favoris**: permettre aux utilisateurs de marquer des projets favoris
- [ ] **Recherche**: ajouter un champ de recherche pour filtrer par nom ou countryId/eventId
- [ ] **Cache offline**: pré-charger les projets pour un usage hors ligne
- [ ] **Intégration tracking**: connecter le layer "tracking" au système de GPS tracking existant
- [ ] **Animation du route**: animer le tracé du circuit principal

## Coordonnées MapMarket

- **Page de listing**: `/admin/mapmarket` ([mapmarket_projects_page.dart](app/lib/admin/mapmarket_projects_page.dart))
- **Wizard d'édition**: `/admin/mapmarket/wizard` ([map_project_wizard_entry_page.dart](app/lib/admin/map_project_wizard_entry_page.dart))
- **Dashboard admin**: Tuile "MapMarket" dans [admin_main_dashboard.dart](app/lib/admin/admin_main_dashboard.dart)
- **Schéma Firestore**: [FIRESTORE_MAP_PROJECTS_SCHEMA.md](FIRESTORE_MAP_PROJECTS_SCHEMA.md)

## Statut

✅ **Bouton "Carte" ajouté dans HomeMapPage3D**  
✅ **BottomSheet avec StreamBuilder fonctionnel**  
✅ **Filtres de publication appliqués**  
✅ **Chargement du style et animation de la caméra**  
⏳ **Chargement des layers et points** (à venir)  
⏳ **Wizard complet** (placeholder actuel)
