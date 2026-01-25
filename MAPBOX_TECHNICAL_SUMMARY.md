# 🗺️ Mapbox Wizard Integration - Technical Summary

## Architecture Overview

```
Circuit Creation Wizard
├── Step 1: Perimeter Definition (_StepPerimetre)
│   ├── Mode Selector: "Draw" | "Preset"
│   ├── Draw Mode (_buildDrawMode)
│   │   └── MapboxWebView (web + token)
│   │       ├── HtmlElementView
│   │       ├── Mapbox GL JS
│   │       └── Navigation Controls
│   │
│   ├── Polygon Points Storage
│   │   └── List<Map<String, double>> _polygonPoints
│   │
│   ├── Visualization
│   │   └── _MapPreviewWidget
│   │       ├── MapboxWebView (if kIsWeb && token)
│   │       ├── CustomPaint Fallback (grid)
│   │       └── Overlay Instructions
│   │
│   └── Status Indicators
│       ├── Badge: "Mapbox" (green) | "Aperçu" (orange)
│       ├── Point Counter: "n points"
│       └── Validation State
│
└── Steps 2-5: Other steps (Tiles, Route, Segments, Publish)
```

## Key Components

### 1. Token Management
```dart
const _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
```
- **Safe**: Empty string if not provided at build time
- **Scope**: Module-level const accessible throughout
- **Type**: `String`
- **Build-time**: Passed via `--dart-define=MAPBOX_ACCESS_TOKEN="..."`

### 2. Conditional Rendering
```dart
final useMapbox = kIsWeb && _mapboxToken.isNotEmpty;

if (useMapbox)
  MapboxWebView(...)
else
  CustomPaint(painter: _GridPainter(), ...)
```

### 3. Point Capture Flow
```
User Tap/Click
  ↓
InkWell onTap (overlay)
  ↓
_addPoint(lat, lng)
  ↓
_polygonPoints.add({'lat': lat, 'lng': lng})
  ↓
setState() → UI Update
  ↓
Display: Point Counter, Preview Drawn Points
```

### 4. Visualization Stack (Z-order)
```
Top:    Overlay Instructions (conditional based on Mapbox)
        FAB Controls (Undo, Clear)
        Status Badge (Mapbox/Aperçu)
        ↓
Mid:    MapboxWebView (or CustomPaint Grid)
        InkWell (point capture layer)
        ↓
Bottom: Container (background, border, shadow)
```

## Web View Integration

### MapboxWebView Details
```dart
MapboxWebView(
  accessToken: _mapboxToken,        // Public pk_... token
  initialLat: 16.2410,              // Guadeloupe center
  initialLng: -61.5340,
  initialZoom: 12.5,                // Departement-level view
  styleUrl: 'mapbox://styles/mapbox/streets-v12'
)
```

### HtmlElementView Setup
```dart
HtmlElementView(
  viewType: 'mapbox-web-view',
  onPlatformViewCreated: (id) {
    // Initialize Mapbox GL JS
    // Register event listeners
    // Add controls
  }
)
```

### Mapbox GL JS Initialization
```javascript
mapboxgl.accessToken = 'pk_...';
const map = new mapboxgl.Map({
  container: domElement,
  style: 'mapbox://styles/mapbox/streets-v12',
  center: [-61.534, 16.241],
  zoom: 12.5,
  pitch: 45,
  bearing: 0,
  antialias: true
});

// Add Navigation Control
map.addControl(new mapboxgl.NavigationControl());

// Add 3D Buildings
map.on('load', () => add3dBuildings(map));
```

## State Management

### Per-Step State (_StepPerimetreState)
```dart
List<Map<String, double>> _polygonPoints = [];
String _selectedMode = 'draw';        // 'draw' | 'preset'
String? _selectedPreset;
bool _isValidated = false;

Methods:
- _addPoint(lat, lng)     → Add new point
- _undoLastPoint()        → Remove last
- _clearPolygon()         → Clear all
- _validatePerimeter()    → Lock perimeter
```

### Auto-Save System
```dart
_startAutoSave()          // Every 30 seconds
_saveDraft()              // Via SharedPreferences
_loadDraft()              // On init
```

## Error Handling

### Token Missing
```
Environment: MAPBOX_ACCESS_TOKEN = ""
Result: _mapboxToken = ""
Behavior: Fallback to CustomPaint grid
Visual: "Mapbox nécessite MAPBOX_ACCESS_TOKEN" message
```

### Token Invalid
```
Environment: MAPBOX_ACCESS_TOKEN = "invalid_token"
Result: Mapbox GL JS fails to load
Visual: Map remains blank (handled by Mapbox)
Fallback: User sees no content (not ideal - could add error UI)
```

### Non-Web Platform
```
kIsWeb = false
Result: MapboxWebView skipped
Visual: CustomPaint grid shown
Reason: Mapbox Web only, native platforms use custom grid
```

## Performance Considerations

### 1. **Lazy Initialization**
```dart
Future.delayed(const Duration(milliseconds: 100), () {
  _initMapbox(container);
});
```
- Ensures DOM ready before JS initialization
- Prevents race conditions

### 2. **Memory Management**
```dart
@override
void dispose() {
  _autoSaveTimer?.cancel();
  super.dispose();
}
```

### 3. **Gesture Handling**
- InkWell overlay for tap capture (minimal overhead)
- No native Mapbox click listeners (future enhancement)
- Single-threaded UI interactions

## Testing Vectors

### Unit Tests
```dart
test('Token from environment', () {
  expect(_mapboxToken, isNotEmpty);
});

test('Point addition', () {
  _addPoint(16.0, -61.0);
  expect(_polygonPoints.length, equals(1));
});

test('Undo works', () {
  _addPoint(16.0, -61.0);
  _undoLastPoint();
  expect(_polygonPoints.length, equals(0));
});
```

### Widget Tests
```dart
testWidgets('MapboxWebView renders when token available', (tester) async {
  await tester.pumpWidget(TestApp());
  expect(find.byType(MapboxWebView), findsOneWidget);
});

testWidgets('Grid painter shows without token', (tester) async {
  // Override _mapboxToken = ""
  await tester.pumpWidget(TestApp());
  expect(find.byType(CustomPaint), findsOneWidget);
});
```

### Integration Tests
```dart
testWidgets('Full draw flow', (tester) async {
  await tester.pumpWidget(App());
  
  // Tap to add points
  await tester.tap(find.byType(InkWell));
  await tester.pumpAndSettle();
  expect(find.byText('1 points'), findsOneWidget);
  
  // Undo
  await tester.tap(find.byIcon(Icons.undo));
  await tester.pumpAndSettle();
  expect(find.byText('0 points'), findsOneWidget);
});
```

## Browser Compatibility

| Browser | Mapbox GL JS | Status |
|---------|-------------|--------|
| Chrome  | ✅ Full    | Latest versions |
| Firefox | ✅ Full    | Latest versions |
| Safari  | ✅ Full    | Latest versions |
| Edge    | ✅ Full    | Latest versions |
| IE 11   | ❌ Not supported | Too old |

## Mobile Support Status

| Platform | Support | Notes |
|----------|---------|-------|
| Web      | ✅ Full Mapbox | With token |
| iOS      | ⚠️ Grid fallback | No WebView Mapbox |
| Android  | ⚠️ Grid fallback | No WebView Mapbox |
| Desktop  | ✅ Full Mapbox | If built for web |

## Future Enhancement Hooks

### Hook 1: Mapbox Click Events
```dart
map.on('click', (e) {
  final lat = e.lngLat.lat;
  final lng = e.lngLat.lng;
  // Bridge to Dart: _addPoint(lat, lng)
});
```

### Hook 2: Feature Queries
```dart
final features = map.querySourceFeatures('composite', {
  'layers': ['building']
});
// Use for building detection
```

### Hook 3: GeoJSON Layers
```dart
map.addSource('perimeter', {
  'type': 'geojson',
  'data': geoJsonFeature
});
map.addLayer({
  'id': 'perimeter-layer',
  'type': 'fill',
  'source': 'perimeter',
  'paint': {...}
});
```

---

## Deployment Checklist

- [x] Code compiles
- [x] Imports correct
- [x] Token const defined
- [x] Conditional rendering working
- [x] Fallback to grid available
- [x] UI overlays adaptive
- [x] Status badges showing
- [ ] Test with actual token
- [ ] Verify on production domain
- [ ] Check token restrictions

---

**Technical Lead**: Flutter Web Team  
**Last Updated**: 2025-01-24  
**Version**: 1.0 (MVP)  
**Status**: 🟢 Ready for QA
