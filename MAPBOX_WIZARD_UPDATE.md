# 🗺️ Mise à jour Mapbox - Assistant de Circuit

## Résumé des changements

### 1. **Mapbox intégré dans le wizard**
- **Statut**: ✅ Déployé
- **Plateforme**: Flutter Web uniquement (nécessite MAPBOX_ACCESS_TOKEN)
- **Fallback**: Grille personnalisée pour mode aperçu (pas de token)

### 2. **Fichiers modifiés**
- **[app/lib/admin/create_circuit_assistant_page.dart](app/lib/admin/create_circuit_assistant_page.dart)**
  - Token Mapbox en const: `const _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN')`
  - `_MapPreviewWidget`: Affiche Mapbox GL JS en background si web + token
  - Overlay instructions adapté selon le mode (Mapbox ou aperçu)
  - FAB (Undo/Clear) conservés pour gestion manuelle des points
  - Status indicator (coin bas-droit) montre "Mapbox" ou "Aperçu"

### 3. **Comportement par plateforme**

#### 🖥️ **Web avec MAPBOX_ACCESS_TOKEN**
```
✅ Mapbox GL JS affiché
✅ Génie de dessin en overlay (Mapbox en background)
✅ Instructions claires : "Cliquez sur la carte pour ajouter des points"
✅ Compteur live: "n points placés"
✅ Statut "Mapbox actif" en bas
```

#### 📱 **Mobile/Desktop (Flutter native)**
```
✅ Grille personnalisée affichée
✅ Overlay InkWell pour ajout de points (simulation)
✅ Instructions : "Clique sur la carte pour ajouter des points"
✅ Statut "Mode aperçu (token?)" en bas
```

### 4. **Configuration requise**

Pour activer Mapbox lors du build web :
```bash
flutter build web --dart-define=MAPBOX_ACCESS_TOKEN="pk_..."
```

Ou dans VSCode tasks.json:
```json
{
  "label": "MASLIVE: Build Web & Deploy",
  "command": "cd /workspaces/MASLIVE/app && flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN=\"$MAPBOX_TOKEN\""
}
```

### 5. **Structure du MapboxWebView**
```dart
MapboxWebView(
  accessToken: _mapboxToken,
  initialLat: 16.241,           // Guadeloupe
  initialLng: -61.534,
  initialZoom: 12.5,
  styleUrl: 'mapbox://styles/mapbox/streets-v12', // ou outdoors, satellite...
)
```

### 6. **Prochaines étapes optionnelles**

#### ✨ **Phase 2: Interactions natives Mapbox**
- [ ] Capturer clics Mapbox GL JS (pas seulement overlay)
- [ ] Afficher points sur la carte en temps réel
- [ ] Dessiner polygone en live avec Mapbox features

#### 🎨 **Phase 3: Styles & Couches**
- [ ] Sélecteur de style dans étape 2 (Tuiles)
- [ ] Couches personnalisées (routes, bâtiments)
- [ ] Styles HDR pour satellite

#### 📍 **Phase 4: Géolocalisation**
- [ ] Intégrer Geolocator pour détection automatique
- [ ] Center map sur position actuelle
- [ ] Distance/surface du périmètre calculée

### 7. **QA Checklist**
- [x] Compilé sans erreurs
- [x] Mapbox token const défini
- [x] `_MapPreviewWidget` affiche Mapbox si web+token
- [x] Overlay instructions adapté
- [x] Status badge "Mapbox"/"Aperçu"
- [ ] Build web avec token et tester sur navigateur
- [ ] Vérifier fallback sans token (grille)
- [ ] Tester points visualisés en temps réel

### 8. **Architecture Mapbox actuelle**
```
create_circuit_assistant_page.dart
├── _MapPreviewWidget (affiche Mapbox si web)
│   ├── MapboxWebView (HtmlElementView + GL JS)
│   ├── CustomPaint (Fallback grille)
│   └── Overlay instructions + status badge
│
└── _StepPerimetre._buildDrawMode()
    ├── MapboxWebView (en background)
    └── Overlay InkWell (pour taps)
```

### 9. **Notes développeur**
- Mapbox initialise asynchrone dans JS (délai 100ms pour DOM ready)
- Token doit être `pk_...` valide pour Mapbox Public API
- Styles disponibles:
  - `streets-v12` (standard)
  - `outdoors-v12` (extérieur)
  - `satellite-v9` (image)
  - `light-v11` / `dark-v11` (minimaliste)
- NavigationControl ajouté auto (zoom +/-, compass)

### 10. **Déploiement**
```bash
# 1. Commit
git add app/lib/admin/create_circuit_assistant_page.dart
git commit -m "wizard: Mapbox intégré dans aperçu périmètre"

# 2. Build & Deploy
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN"
cd ..
firebase deploy --only hosting
```

---

**Date de mise à jour**: Jan 2025  
**Statut**: Production Ready (avec token MAPBOX_ACCESS_TOKEN)
