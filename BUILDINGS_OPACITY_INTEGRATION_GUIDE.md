# Guide d'intégration - Transparence des Immeubles 3D

## 📋 Vue d'ensemble

Ce système permet de contrôler la transparence des bâtiments 3D Mapbox en temps réel via l'interface Style Pro.

### Composants créés :

✅ **RouteStyleConfig** - Champs `buildingOpacity` et `buildings3dEnabled` ajoutés
✅ **MapBuildingsStyleService** - Service abstrait (web/natif)
✅ **BuildingOpacityControl** - Widget UI premium avec slider et presets
✅ **JavaScript Bridge** - Fonctions pour contrôle web
✅ **RouteStyleControlsPanel** - Intégration du widget

---

## 🚀 Intégration dans vos pages existantes

### 1. Importer le service

```dart
import 'package:masslive/route_style_pro/services/map_buildings_style_service_web.dart'
    if (dart.library.io) 'package:masslive/route_style_pro/services/map_buildings_style_service_native.dart';
```

### 2. Créer une instance du service

```dart
class MyMapPage extends StatefulWidget {
  // ...
}

class _MyMapPageState extends State<MyMapPage> {
  late final MapBuildingsStyleService _buildingsService;
  RouteStyleConfig? _currentStyle;

  @override
  void initState() {
    super.initState();
    
    // Web ou Native selon la plateforme
    _buildingsService = MapBuildingsStyleServiceWeb(); // ou Native
  }
  
  // ...
}
```

### 3. Appliquer l'opacité lors du chargement

```dart
Future<void> _onMapCreated(MapboxMap map) async {
  // Initialiser la carte...
  
  // Si vous avez un RouteStyleConfig chargé depuis Firestore
  if (_currentStyle != null) {
    await _applyBuildingsStyle(_currentStyle!);
  }
}

Future<void> _applyBuildingsStyle(RouteStyleConfig config) async {
  if (!mounted) return;
  
  try {
    // Activer/désactiver les bâtiments
    await _buildingsService.setBuildingsEnabled(config.buildings3dEnabled);
    
    // Définir l'opacité
    if (config.buildings3dEnabled) {
      final success = await _buildingsService.setBuildingsOpacity(
        config.buildingOpacity,
      );
      
      if (success) {
        debugPrint('[BuildingsOpacity] Applied: ${config.buildingOpacity}');
      } else {
        debugPrint('[BuildingsOpacity] Warning: Could not apply opacity');
      }
    }
  } catch (e) {
    debugPrint('[BuildingsOpacity] Error applying style: $e');
  }
}
```

### 4. Réappliquer après changement de style Mapbox

```dart
Future<void> _onStyleLoaded() async {
  // Après qu'un nouveau style Mapbox soit chargé
  
  // Invalider le cache du service (important!)
  if (_buildingsService is MapBuildingsStyleServiceWeb) {
    (_buildingsService as MapBuildingsStyleServiceWeb).invalidateCache();
  } else if (_buildingsService is MapBuildingsStyleServiceNative) {
    (_buildingsService as MapBuildingsStyleServiceNative).invalidateCache();
  }
  
  // Réappliquer le style
  if (_currentStyle != null) {
    await _applyBuildingsStyle(_currentStyle!);
  }
}
```

---

## 🔧 Configuration native (TODO)

Pour l'implémentation native, complétez le code dans :
`lib/route_style_pro/services/map_buildings_style_service_native.dart`

### Exemple avec Mapbox Maps Flutter SDK :

```dart
@override
Future<bool> setBuildingsOpacity(double opacity) async {
  if (_mapboxMap == null) return false;
  
  try {
    final layerId = await findBuildingLayer();
    if (layerId == null) return false;
    
    // API Mapbox Maps Flutter (à adapter selon votre version)
    await _mapboxMap.style.setStyleLayerProperty(
      layerId,
      'fill-extrusion-opacity',
      opacity.clamp(0.0, 1.0),
    );
    
    _log('apply opacity=$opacity layer=$layerId success');
    return true;
  } catch (e) {
    _log('setBuildingsOpacity error: $e');
    return false;
  }
}
```

---

## 📱 Utilisation dans le wizard

Le widget est déjà intégré dans `RouteStyleControlsPanel`. Pour l'utiliser dans vos circuits :

```dart
// Dans circuit_wizard_pro_page.dart (déjà fait)

// 1. Charger le config depuis Firestore
final proCfg = tryParseRouteStylePro(data['routeStylePro']);

// 2. Afficher le panneau de contrôles
RouteStyleControlsPanel(
  config: proCfg ?? RouteStyleConfig(),
  onChanged: (newConfig) {
    // Appliquer immédiatement l'opacité
    _applyBuildingsStyle(newConfig);
    
    // Sauvegarder la config
    _saveStyleConfig(newConfig);
  },
  // ...
)
```

---

## 🎨 Personnalisation du widget UI

Le widget `BuildingOpacityControl` peut être personnalisé. Modifiez dans :
`lib/route_style_pro/ui/widgets/building_opacity_control.dart`

### Changer les presets :

```dart
static const List<({String label, double value})> presets = [
  (label: 'Opaque', value: 1.0),
  (label: 'Confort', value: 0.70),
  (label: 'Moyen', value: 0.50),
  (label: 'Léger', value: 0.30),
  (label: 'Fantôme', value: 0.10),
];
```

### Changer la valeur par défaut :

```dart
static const double defaultOpacity = 0.60; // Modifier ici
```

---

## 🧪 Plan de test manuel

### Test 1 : Slider + Presets
1. Ouvrir une page avec Style Pro
2. Localiser le widget "Transparence immeubles"
3. Déplacer le slider → les bâtiments doivent devenir plus/moins transparents
4. Cliquer sur "Ghost" → opacité à 20%
5. Cliquer sur "Opaque" → opacité à 100%
6. Vérifier que le preset actif est mis en évidence visuellement

### Test 2 : Toggle Enable/Disable
1. Désactiver le switch "Activer immeubles 3D"
2. Vérifier que les bâtiments disparaissent
3. Vérifier que le slider est grisé (disabled)
4. Réactiver le switch
5. Vérifier que les bâtiments réapparaissent avec la bonne opacité

### Test 3 : Persistance
1. Régler l'opacité à 40%
2. Sauvegarder le circuit/style
3. Naviguer ailleurs
4. Revenir → l'opacité doit être à 40%

### Test 4 : Changement de style Mapbox
1. Régler opacité à 50%
2. Changer le style Mapbox (ex: Streets → Outdoors)
3. Vérifier que l'opacité est réappliquée après le chargement du nouveau style

### Test 5 : Fallback gracieux
1. Utiliser un style sans bâtiments 3D
2. Vérifier qu'aucune erreur n'apparaît
3. Vérifier qu'un message de log indique "no fill-extrusion layer found"

### Test 6 : Multi-cartes (si applicable)
1. Ouvrir plusieurs instances de carte
2. Changer l'opacité sur une carte
3. Vérifier que seule cette carte est affectée

### Test 7 : Performance
1. Déplacer rapidement le slider de 0 à 100
2. Vérifier qu'il n'y a pas de lag
3. Vérifier que la carte reste fluide

### Test 8 : Web vs Native
1. Tester sur web (Chrome/Safari)
2. Tester sur mobile (iOS/Android) une fois le natif implémenté
3. Vérifier que le comportement est identique

### Test 9 : Bouton Réinitialiser
1. Modifier l'opacité plusieurs fois
2. Cliquer sur "Réinitialiser"
3. Vérifier que l'opacité revient à 60%

### Test 10 : Console Logs
1. Ouvrir la console développeur
2. Changer l'opacité
3. Vérifier les logs :
   - `[BuildingsOpacity] layer found: ...`
   - `[BuildingsOpacity] apply opacity=0.55 layer=... success`

---

## ⚠️ Points de vigilance

### 1. IDs de couches
Le système cherche automatiquement les IDs suivants :
- `3d-buildings`
- `building-3d`
- `buildings-3d`
- `maslive-3d-buildings`
- `building`

Si votre style utilise un ID différent, ajoutez-le dans :
```dart
// map_buildings_style_service.dart
static const List<String> possibleLayerIds = [
  '3d-buildings',
  'votre-custom-id-ici', // ← Ajouter ici
  // ...
];
```

### 2. Ordre de chargement
L'opacité doit être appliquée **APRÈS** que :
- La carte soit initialisée
- Le style soit chargé
- Les couches 3D soient créées

### 3. Web : Available après ajout des bâtiments
Sur web, assurez-vous d'appeler `add3DBuildings` **avant** d'appliquer l'opacité :

```dart
await _add3dBuildings();
await Future.delayed(Duration(milliseconds: 100)); // Laisser le temps au layer
await _applyBuildingsStyle(config);
```

### 4. Native : Injection de MapboxMap
N'oubliez pas d'injecter l'instance de la carte :

```dart
_buildingsService.setMapInstance(_mapboxMap);
```

---

## 🐛 Debugging

### Logs disponibles

En mode debug, tous les appels affichent des logs préfixés `[BuildingsOpacity]` :

```
[BuildingsOpacity] layer found: maslive-3d-buildings
[BuildingsOpacity] apply opacity=0.60 layer=maslive-3d-buildings success
[BuildingsOpacity] no fill-extrusion layer found in current style
[BuildingsOpacity] cache invalidated
```

### Problèmes courants

**Opacité ne s'applique pas :**
- Vérifier que la couche 3D existe dans le style
- Vérifier l'ID de la couche dans les logs
- Vérifier que le style est complètement chargé

**Les bâtiments ne disparaissent pas :**
- Vérifier que `setBuildingsEnabled(false)` est bien appelé
- Sur web, vérifier la console JS pour les erreurs

**L'opacité n'est pas sauvegardée :**
- Vérifier que `toJson()` et `fromJson()` fonctionnent
- Vérifier la sauvegarde Firestore du `routeStylePro`

**Lag lors du déplacement du slider :**
- Implémenter un debounce si nécessaire
- Utiliser `onChangeEnd` au lieu de `onChanged`

---

## 📚 Références techniques

### Propriété Mapbox utilisée
- `fill-extrusion-opacity` : Contrôle l'opacité des extrusions 3D (0.0 à 1.0)

### Documentation Mapbox
- [Fill Extrusion Layer](https://docs.mapbox.com/mapbox-gl-js/style-spec/layers/#fill-extrusion)
- [Paint Properties](https://docs.mapbox.com/mapbox-gl-js/style-spec/layers/#paint-property)

### Architecture
```
RouteStyleConfig (modèle)
    ↓
BuildingOpacityControl (UI widget)
    ↓
RouteStyleControlsPanel (intégration)
    ↓
MapBuildingsStyleService (abstraction)
    ↙               ↘
Web (JS bridge)    Native (SDK)
    ↓               ↓
Mapbox GL JS      Mapbox Maps SDK
```

---

## ✅ Checklist d'intégration complète

- [x] RouteStyleConfig mis à jour
- [x] Service abstrait créé
- [x] Implémentation web créée
- [ ] Implémentation native complétée (TODO)
- [x] Widget UI créé
- [x] Intégration dans RouteStyleControlsPanel
- [x] Fonctions JavaScript ajoutées
- [ ] Réapplication automatique  implémentée dans vos pages
- [ ] Tests manuels passés
- [ ] Documentation lue et comprise

---

## 🎯 Prochaines étapes

1. **Compléter l'implémentation native** dans `map_buildings_style_service_native.dart`
2. **Intégrer dans home_map_page_3d.dart** la réapplication automatique
3. **Tester sur toutes les plateformes** (web, iOS, Android)
4. **Optimiser les performances** si nécessaire (debounce)
5. **Ajouter mode auto** (optionnel : ajuster opacité selon zoom)

---

## 💡 Améliorations futures (optionnelles)

### Mode Auto
Ajuster automatiquement l'opacité selon le niveau de zoom :

```dart
void _updateBuildingsOpacityForZoom(double zoom) {
  double opacity;
  if (zoom < 14) {
    opacity = 0.0; // Invisible en zoom faible
  } else if (zoom < 16) {
    opacity = 0.4; // Transparent en zoom moyen
  } else {
    opacity = 0.7; // Plus opaque en zoom élevé
  }
  
  _buildingsService.setBuildingsOpacity(opacity);
}
```

### Preview en miniature
Ajouter une petite carte preview montrant l'effet de l'opacité.

### Synchronisation multi-utilisateur
Si plusieurs utilisateurs éditent le même circuit, synchroniser l'opacité via Firestore en temps réel.

---

**Auteur:** GitHub Copilot (Claude Sonnet 4.5)  
**Date:** Mars 2026  
**Version:** 1.0.0
