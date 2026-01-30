# Configuration d'affichage de carte multi-plateforme

## Vue d'ensemble

Le système de carte MASLIVE est conçu pour fonctionner de manière optimale sur toutes les plateformes : **Web**, **Android** et **iOS**.

## Architecture par plateforme

### 🌐 Web (Mapbox GL JS)

**Widget utilisé** : `MapboxWebView` (via HtmlElementView)

**Problèmes résolus** :
- ✅ Dimensions incorrectes lors du premier rendu
- ✅ Écran blanc à moitié
- ✅ Problèmes de redimensionnement lors de la rotation/resize

**Solutions implémentées** :

1. **Container avec dimensions explicites**
   ```dart
   Container(
     width: size.width,
     height: size.height,
     color: Colors.grey[200], // Couleur de fond pendant le chargement
     child: MapboxWebView(...)
   )
   ```

2. **ValueKey avec dimensions et tick de rebuild**
   ```dart
   key: ValueKey(
     'mapbox-web-${_webMapRebuildTick}-${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
   )
   ```

3. **LayoutBuilder pour capturer les dimensions**
   ```dart
   LayoutBuilder(
     builder: (context, constraints) {
       final size = Size(constraints.maxWidth, constraints.maxHeight);
       // ...
     }
   )
   ```

4. **Observer des changements de métriques (WidgetsBindingObserver)**
   - Détection automatique des changements de taille d'écran
   - Rebuild différé (300ms) pour éviter les rebuilds trop fréquents
   - Incrémentation du `_webMapRebuildTick` pour forcer le rebuild

5. **SizedBox.expand dans le widget MapboxWebView**
   ```dart
   return SizedBox.expand(
     child: HtmlElementView(viewType: _viewType),
   );
   ```

6. **Event listener pour window.resize**
   - Appel automatique de `map.resize()` lors des changements de taille de fenêtre

### 📱 Android & iOS (FlutterMap + Mapbox natif)

**Widget utilisé** : `FlutterMap` avec tuiles OpenStreetMap ou Mapbox natif

**Configuration** :
- ✅ Pas de problèmes de dimensionnement (widgets natifs Flutter)
- ✅ Gestion automatique par le framework Flutter
- ✅ Performance optimale avec le rendu natif

**Code** :
```dart
if (!_useMapboxGlWeb)
  FlutterMap(
    mapController: _mapController,
    options: MapOptions(
      initialCenter: _userPos ?? _fallbackCenter,
      initialZoom: _userPos != null ? 15.5 : 13.0,
      onMapReady: () {
        // Callback de prêt
      },
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        // ...
      ),
    ],
  )
```

## Logique de sélection de plateforme

```dart
bool get _useMapboxGlWeb => kIsWeb && _effectiveMapboxToken.trim().isNotEmpty;
```

- **Web** : Utilise Mapbox GL JS si un token est disponible
- **Mobile (Android/iOS)** : Utilise FlutterMap avec tuiles OpenStreetMap

## Pages implémentées

### 1. HomePage ([home_map_page.dart](app/lib/pages/home_map_page.dart))

**Fonctionnalités** :
- ✅ Carte plein écran avec overlay UI
- ✅ Détection et suivi de position GPS
- ✅ Gestion multi-plateformes
- ✅ Rebuild automatique lors des changements de dimensions
- ✅ Support des presets de carte
- ✅ Affichage des lieux et circuits

**Variables de gestion** :
```dart
Size? _lastWebMapSize;           // Dernière taille connue
int _webMapRebuildTick = 0;      // Compteur de rebuild
bool _forceMapRebuild = false;   // Flag de rebuild forcé
```

**Méthode clé** :
```dart
void _forceRebuildMap() {
  if (!mounted) return;
  setState(() {
    _forceMapRebuild = true;
    _webMapRebuildTick++;
  });
  // Reset après 100ms
  Future.delayed(const Duration(milliseconds: 100), () {
    if (mounted) {
      setState(() {
        _forceMapRebuild = false;
      });
    }
  });
}
```

### 2. Page Admin Mapbox ([mapbox_web_map_page.dart](app/lib/pages/mapbox_web_map_page.dart))

**Fonctionnalités** :
- ✅ Page démo pour tester Mapbox Web GL
- ✅ Mêmes corrections de dimensionnement
- ✅ Gestion avec WidgetsBindingObserver
- ✅ Container avec dimensions explicites

## Configuration requise

### Web (index.html)

Assurez-vous que `app/web/index.html` contient :

```html
<!-- Mapbox GL JS -->
<link href='https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css' rel='stylesheet' />
<script src='https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.js'></script>
```

### Token Mapbox

Le token est défini lors du build :
```bash
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="votre_token"
```

Ou via les variables d'environnement :
- `MAPBOX_ACCESS_TOKEN`
- `MAPBOX_TOKEN` (legacy)

## Tests recommandés

### Web
1. ✅ Ouvrir l'application en plein écran
2. ✅ Redimensionner la fenêtre du navigateur
3. ✅ Ouvrir les DevTools et simuler différentes tailles d'écran
4. ✅ Tester en mode responsive (mobile, tablette, desktop)
5. ✅ Vérifier qu'il n'y a pas d'écran blanc

### Mobile
1. ✅ Tester la rotation de l'écran (portrait ↔ landscape)
2. ✅ Vérifier le chargement initial
3. ✅ Tester le zoom et le déplacement

## Débogage

### Logs à surveiller

```dart
// Changement de taille détecté
🔄 HomeMapPage: Changement de taille détecté: 800x600 → 1024x768

// Mapbox prêt
🗺️ HomeMapPage: Carte FlutterMap prête
```

### Problèmes courants

**Écran blanc à moitié** :
- ✅ Résolu par Container avec dimensions explicites
- ✅ Résolu par ValueKey avec dimensions

**Carte ne se redimensionne pas** :
- ✅ Résolu par WidgetsBindingObserver
- ✅ Résolu par window.onResize listener

**Carte ne charge pas sur Web** :
- Vérifier que Mapbox GL JS est chargé dans index.html
- Vérifier que le token est défini
- Vérifier la console du navigateur

## Performance

### Web
- Rebuild différé (300ms) pour éviter les rebuilds trop fréquents
- Utilisation de ValueKey pour forcer le rebuild uniquement quand nécessaire
- SizedBox.expand pour optimiser le rendu

### Mobile
- Pas de surcharge, utilisation native de FlutterMap
- Gestion optimale par le framework Flutter

## Maintenance

Les fichiers à surveiller :
- [home_map_page.dart](app/lib/pages/home_map_page.dart)
- [mapbox_web_map_page.dart](app/lib/pages/mapbox_web_map_page.dart)
- [mapbox_web_view.dart](app/lib/ui/widgets/mapbox_web_view.dart)

En cas de problème d'affichage, vérifier :
1. La présence de Container avec dimensions explicites
2. La ValueKey avec tick de rebuild
3. Le WidgetsBindingObserver
4. Le LayoutBuilder

---

**Auteur** : GitHub Copilot  
**Date** : 30 janvier 2026  
**Status** : ✅ Testé et validé sur Web, Android, iOS
