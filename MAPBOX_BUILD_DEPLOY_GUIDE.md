# 🚀 MAPBOX FIXES - BUILD & DEPLOY GUIDE

## 📋 Pre-Deploy Checklist

- [x] `mapbox_circuit.js` - All validations added ✅
- [x] `mapbox_web_circuit_map.dart` - All logging added ✅
- [x] `index.html` - Correct script loading order ✅
- [x] `mapbox_token_service.dart` - Token initialization ✅
- [x] No compilation errors
- [x] No silent catch blocks
- [x] Boolean returns from JS functions
- [x] Emoji logging for debugging

## 🔨 Build Steps

### Option 1: With Mapbox Token (Recommended)

```bash
cd /workspaces/MASLIVE/app

# Make sure dependencies are fresh
flutter pub get

# Build web with token
export MAPBOX_ACCESS_TOKEN="your_mapbox_token_here"
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"

# Go back and deploy
cd ..
firebase deploy --only hosting
```

### Option 2: Use Firebase Deploy Task (One-Click)

There's a built-in task that does everything:

```bash
# In VS Code: Terminal → Run Task
# Select: "MASLIVE: Déployer Hosting (1 clic)"
```

Or from command line:

```bash
cd /workspaces/MASLIVE/app
flutter pub get && \
TOKEN=${MAPBOX_ACCESS_TOKEN:-${MAPBOX_PUBLIC_TOKEN:-${MAPBOX_TOKEN:-}}} && \
if [ -n "$TOKEN" ]; then \
  flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$TOKEN"; \
else \
  flutter build web --release; \
fi && \
cd .. && \
firebase deploy --only hosting
```

## 🧪 Post-Deploy Testing

### 1. Test in Browser Console

```javascript
// Check if Mapbox API is available
console.log(window.masliveMapbox);

// Should output: { init, setData }
```

### 2. Test in Application

1. Go to `Admin → Créer Circuit`
2. Open Developer Tools (F12) → Console
3. Start creating a circuit
4. Check for logs with emoji:
   - 🔑 Token loaded
   - 🗺️ Map created
   - ✅ Mapbox loaded
   - ✅ All data updated

### 3. Test Circuit Creation

1. Draw a circuit perimeter
2. Set a route
3. Add segments
4. Verify map updates in real-time
5. Check for errors in console (should be none if working correctly)

## 📊 Expected Console Output (Debug Mode)

```
🗺️ Initialisation Mapbox...
  • Token: pk_live_****
  • Container: mapbox_container_abc123
  • Coordonnées: [-61.534, 16.241]
🔑 Token: pk_live_****
🗺️ Map created
✅ Mapbox loaded
✅ Mapbox initialisé avec succès
📤 Envoi des données GeoJSON à Mapbox...
✅ Périmètre mis à jour
✅ Route mis à jour
✅ Segments mis à jour
✅ Toutes les données mises à jour
✅ Données envoyées avec succès
```

## ⚠️ Troubleshooting

### "Map not initialized" Error

**Cause**: init() failed (token empty, container not found, mapboxgl not loaded)

**Solution**:
1. Check console for 🔑 Token log - is token present?
2. Check console for 🗺️ Map created - did DOM element exist?
3. Check that mapbox-gl.js loaded from CDN (Network tab)

### "Source not found" Error

**Cause**: setData() called before sources created

**Solution**:
1. Check console for ✅ Mapbox loaded
2. Ensure ensureSourcesAndLayers() called first
3. Check delay is 500ms (gives time for sources to be created)

### "Données non affichées" (Data not showing)

**Cause**: GeoJSON data incorrect or empty

**Solution**:
1. Check console for 📤 Envoi des données... log
2. Check if ✅ Données envoyées appears
3. Open Network tab and inspect GeoJSON data being sent
4. Verify coordinates are valid [lng, lat] format

### Token Not Loading

**Cause**: Token not passed via --dart-define

**Solution**:
1. Use full command: `flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="pk_..."`
2. Or set environment variable: `export MAPBOX_ACCESS_TOKEN="pk_..."`
3. Or manually set in SharedPreferences via dialog in app

## 🔍 Logging Reference

| Log | Meaning |
|-----|---------|
| 🔑 Token | Token successfully set |
| 🗺️ Map created | Mapbox map container created |
| ✅ Mapbox loaded | Map ready for data updates |
| 📤 Envoi des données... | GeoJSON data being sent |
| ✅ Périmètre mis à jour | Perimeter drawn on map |
| ✅ Route mis à jour | Route drawn on map |
| ✅ Segments mis à jour | Route segments drawn on map |
| ⚠️ Source non trouvée | Source doesn't exist (check timing) |
| ❌ Token Mapbox vide | Empty token (configure it) |
| ❌ Mapbox error | Mapbox GL JS error (check console) |

## 📝 Important Notes

1. **Console Logs Only in Debug**: Logs with emoji only appear in debug mode (not in Release unless verbose logging enabled)
2. **Token Priority**: App looks for token in this order:
   - `--dart-define=MAPBOX_ACCESS_TOKEN=...`
   - `--dart-define=MAPBOX_TOKEN=...` (legacy)
   - SharedPreferences (persisted by user)
3. **Source Timing**: ensureSourcesAndLayers() must run before setData()
4. **Delay**: 500ms delay after init gives map time to load before data push
5. **Return Values**: init() and setData() return true/false for success/failure

## 🎯 Success Criteria

After deployment, the app is working correctly if:

- ✅ Circuit wizard loads without errors
- ✅ Map displays in wizard step 2
- ✅ Drawing perimeter/route works
- ✅ Console shows emoji logs (🔑🗺️✅📤)
- ✅ No console errors appear
- ✅ Map updates when drawing/editing
- ✅ All shapes (perimeter, route, segments) display correctly

## 🚀 One-Click Deploy (Recommended)

In VS Code:
1. Terminal → Run Task
2. Select: "MASLIVE: 🚀 Commit + Push + Build + Deploy (Token Mapbox)"
3. Or: "MASLIVE: Déployer Hosting (1 clic)"

This will:
- Run flutter pub get
- Detect MAPBOX_ACCESS_TOKEN environment variable
- Build web release
- Deploy to Firebase hosting
- All in one command ✅

---
**Ready to deploy!** 🎉
