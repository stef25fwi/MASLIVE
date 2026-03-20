# ⚡ OPTIMISATIONS RAPIDES - SPLASHSCREEN

Guide d'implémentation des optimisations rapides pour accélérer le chargement du splashscreen.

---

## 🚀 QUICK WIN 1 : Réduire Délai Minimum Splash

### Changement simple : 2500ms → 1800ms

**Fichier**: `lib/pages/splash_wrapper_page.dart` (line 38)

**Code actuel**:
```dart
final remainingMs = 2500 - elapsedMs;
```

**Code optimisé**:
```dart
// Réduit de 2500ms à 1800ms (700ms de gain)
final remainingMs = 1800 - elapsedMs;
```

**Bénéfice**: 
- ✅ 700ms visible immédiat
- ✅ Aucune impact négatif (1.8s c'est déjà "long")
- ✅ Changement 1 ligne

**Implémentation**:
```dart
// Vérifier d'abord avec 1800ms, puis tester 1500ms si acceptable
// Timeline teste:
// 1800ms: gain 700ms visible
// 1500ms: gain 1s visible (risqué visuellement)
```

---

## 🚀 QUICK WIN 2 : Paralleliser Services de Bootstrap

### Changement : Séquentiel → Parallèle

**Fichier**: `lib/main.dart` (lines 159-173)

**Code actuel** (séquentiel):
```dart
// 3) Mapbox token warmup: SharedPreferences (rapide) mais on timeoute par sûreté.
try {
  await MapboxTokenService.warmUp().timeout(const Duration(seconds: 2));
} catch (e) {
  debugPrint('⚠️ Bootstrap: MapboxTokenService.warmUp skipped: $e');
}

// 4) LanguageService: doit exister avant build() (Get.find). Init best-effort.
try {
  await Get.putAsync(() => LanguageService().init())
      .timeout(const Duration(seconds: 3));
} catch (e) {
  debugPrint('⚠️ Bootstrap: LanguageService init fallback: $e');
}
```

**Code optimisé** (parallèle):
```dart
// 3+4) Services parallèles (non-Firebase)
try {
  await Future.wait<void>([
    // Mapbox token
    MapboxTokenService.warmUp()
        .timeout(const Duration(seconds: 2))
        .catchError((e) {
      debugPrint('⚠️ Bootstrap: MapboxTokenService.warmUp skipped: $e');
    }),
    // Language service
    Get.putAsync(() => LanguageService().init())
        .timeout(const Duration(seconds: 2)) // Réduit aussi
        .catchError((e) {
      debugPrint('⚠️ Bootstrap: LanguageService init fallback: $e');
      if (!Get.isRegistered<LanguageService>()) {
        Get.put(LanguageService());
      }
    }),
    // Stripe (si natif)
    if (!kIsWeb)
      Stripe.instance
          .applySettings()
          .timeout(const Duration(seconds: 2)) // Réduit aussi
          .catchError((e) {
        debugPrint('⚠️ Bootstrap: Stripe applySettings skipped: $e');
      }),
  ]);
} catch (_) {
  // Silencieux
}
```

**Bénéfice**:
- ✅ 0.5-1.5s de gain (services parallèles au lieu de séquentiel)
- ✅ Timeout aussi réduits (plus rapides à échouer)
- ✅ Firebase reste bloquant (requis)

**Timing comparé**:
```
AVANT: 50 + 200 + 100 + 150 = 500ms séquentiel
APRÈS: max(200, 100, 150) = 200ms parallèle
GAIN: 300ms
```

---

## 🚀 QUICK WIN 3 : Tiering du Préchargement Images

### Changement : Charger TOUS les images → Charger seulement critiques

**Fichier**: `lib/services/startup_preload_service.dart`

**Code actuel**:
```dart
static Future<Set<String>> collectSplashImageAssets() async {
  final assets = <String>{..._explicitImages};

  try {
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest =
        jsonDecode(manifestJson) as Map<String, dynamic>;

    for (final assetPath in manifest.keys) {
      if (!_isImageAsset(assetPath)) continue;
      if (assetPath.startsWith('assets/images/') ||
          assetPath.startsWith('assets/shop/')) {
        assets.add(assetPath); // ⚠️ Tous les assets!
      }
    }
  } catch (_) {}

  return assets;
}
```

**Code optimisé** (Tier 1 + Tier 2):
```dart
static final List<String> _tier1Critical = <String>[
  'assets/splash/wom1.png',
  'assets/images/maslivelogo.png',
  'assets/images/maslivesmall.png',
  'assets/images/icon wc parking.png',
  // Ajouter ici SEULEMENT les 10-15 images du splash + header
];

static Future<Set<String>> collectSplashImageAssets({
  bool criticalOnly = true,
}) async {
  if (criticalOnly) {
    return _tier1Critical.toSet(); // Juste le minimum
  }

  // TIER 2 (chargé après splash)
  final assets = <String>{..._tier1Critical};
  try {
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest =
        jsonDecode(manifestJson) as Map<String, dynamic>;

    for (final assetPath in manifest.keys) {
      if (!_isImageAsset(assetPath)) continue;
      if (assetPath.startsWith('assets/images/') ||
          assetPath.startsWith('assets/shop/')) {
        assets.add(assetPath);
      }
    }
  } catch (_) {}

  return assets;
}
```

**Alors dans splash_wrapper_page.dart**:
```dart
Future<void> _startAssetPreload() async {
  // TIER 1: Critical images only
  final criticalAssets = 
    await StartupPreloadService.collectSplashImageAssets(criticalOnly: true);
  
  if (!mounted) return;

  try {
    for (final path in criticalAssets) {
      await precacheImage(AssetImage(path), context);
    }
  } catch (_) {}

  if (!mounted) return;
  _assetsReady = true; // ✅ Splash peut disparaître
  _tryHideSplash();

  // TIER 2: Charger resto APRÈS splash visible
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final allAssets = 
      await StartupPreloadService.collectSplashImageAssets(criticalOnly: false);
    
    final nonCritical = allAssets.difference(criticalAssets);
    
    for (final path in nonCritical) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
  });
}
```

**Bénéfice**:
- ✅ 600-1000ms de gain (précharge moins bloquante)
- ✅ Splash disparaît plus vite
- ✅ Autres images chargées en arrière-plan sans impacter UX

**Timing comparé**:
```
AVANT: 15-20img × 50ms = 750-1000ms bloquant
APRÈS: 5-7img × 30ms = 150-200ms + async tier2
GAIN: 550-850ms visible
```

---

## 🚀 QUICK WIN 4 : Réduire Firebase Timeout de 12s → 8s

### Changement : Timeout moins agressif

**Fichier**: `lib/main.dart` (line 130)

**Code actuel**:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
).timeout(const Duration(seconds: 12));
```

**Code optimisé**:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
).timeout(const Duration(seconds: 8)); // Réduit de 12s à 8s
```

**Bénéfice**:
- ✅ 4s de gain si Firebase est Down/offline
- ✅ User voit splash natif 4s moins longtemps
- ⚠️ Risque: Firebase timeout réel après 8s rejette aussi
- ✅ Fallback graceful déjà implémenté

**Profiling recommandé avant**:
```dart
// Ajouter temporairement un timer:
final sw = Stopwatch()..start();
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
).timeout(const Duration(seconds: 8));
debugPrint('Firebase init took ${sw.elapsed.inMilliseconds}ms');
```

Mesurer en conditions réelles puis ajuster.

---

## 🚀 QUICK WIN 5 : Map-Only Rendering (HomeMapPage3D)

### Changement : Charger map vierge PUIS ajouter POIs

**Fichier**: `lib/pages/home_map_page_3d.dart` (line ~200-300 initState)

**Impact**: 
- ⚠️ Changement architectural (plus complexe)
- ✅ Gain significatif : 800-1200ms

**Approche simple** (sans refactor lourd):
```dart
@override
void initState() {
  super.initState();
  
  // ✅ Initialiser MAP SEULEMENT
  _initMapWidget();
  
  // ✅ Lancer services EN ARRIÈRE-PLAN (pas d'attente)
  _lazyInitServices();
}

void _initMapWidget() {
  // Juste création MapboxMap controller
  debugPrint('🗺️ Initializing map widget...');
  // Ne pas attendre de callbacks
}

Future<void> _lazyInitServices() async {
  // Lancé en arrière-plan
  try {
    await Future.delayed(Duration(milliseconds: 500)); // Après map visible
    if (!mounted) return;
    
    // Geolocation
    _geo.start();
    
    // POI + style
    _loadFirestoreData();
    
    // Tracking
    _startTracking();
  } catch (e) {
    debugPrint('⚠️ Lazy init error: $e');
  }
}

@override
Widget build(BuildContext context) {
  if (!_isMapReady) {
    return _buildMapEmpty(); // Map vierge = rapide
  }
  return _buildMapComplete(); // Ajouter POIs + contrôles
}

Widget _buildMapEmpty() {
  return MapWidget(...); // Juste la map, pas les POIs
}
```

**Implémentation détaillée**: Voir section "Lazy-load HomeMapPage3D services" dans le rapport principal.

---

## 📋 CHECKLIST IMPLÉMENTATION

### Pour démarrer rapidement (ordre recommandé):

- [ ] **1. Réduire splash delay** (5 minutes)
  - [ ] Modifier ligne 38 de splash_wrapper_page.dart
  - [ ] Test sur device
  - [ ] Commit: "perf: reduce splash minimum delay 2500→1800ms"

- [ ] **2. Paralleliser services** (30 minutes)
  - [ ] Refactor main.dart bootstrap  
  - [ ] Réduire timeout Language + Stripe
  - [ ] Test Firebase timeout en conditions réelles
  - [ ] Commit: "perf: parallelize bootstrap services"

- [ ] **3. Image tier 1/2** (1-2 heures)
  - [ ] Ajouter `_tier1Critical` list
  - [ ] Modifier `collectSplashImageAssets()`
  - [ ] Mise à jour splash_wrapper_page `_startAssetPreload()`
  - [ ] Test: vérifier splash disparaît plus vite
  - [ ] Commit: "perf: tier image preloading (critical→async)"

- [ ] **4. Firebase timeout** (10 minutes)
  - [ ] Ajouter Stopwatch profiling
  - [ ] Mesurer en 3G moyen
  - [ ] Réduire à 8s si safe
  - [ ] Commit: "perf: reduce firebase timeout 12→8s"

- [ ] **5. Map-only rendering** (2-4 heures)
  - [ ] Refactor initState de HomeMapPage3D
  - [ ] Lazy-load POI + tracking
  - [ ] Extensive testing map behavior
  - [ ] Commit: "perf: lazy-load home map services"

---

## 🎯 MESURE DE SUCCÈS

### Avant optimisations (baseline):
```
Device moderne + WiFi rapide:    3-4s
Device moyen + 4G normal:        6-8s
Device ancien + 3G moyen:        10-12s
```

### Après optimisations (objectif):
```
Device moderne + WiFi rapide:    1.5-2s (gain 50%)
Device moyen + 4G normal:        4-5s   (gain 35%)
Device ancien + 3G moyen:        6-8s   (gain 35%)
```

### Metrics à tracker:
1. **Splash visible time** (adb logcat, DevTools)
2. **Splash hide time** (adb logcat + debugPrint)
3. **Map ready time** (mapReadyNotifier.value = true)
4. **TTI** (Time To Interactive)

---

## 🔧 OUTILS DE PROFILING

### Android:
```bash
# Profiler temps de boot
adb logcat | grep "SplashWrapper\|HomeMapPage\|Firebase\|Bootstrap"

# Enregistrer performance
flutter run --profile
# → Flutter DevTools → Timeline tab
```

### iOS:
```bash
# Instruments → App Launch
# Voir chaque stage du bootstrap
```

### Web:
```bash
# DevTools → Performance tab
# F12 → Performance tab → Record
```

---

## 📞 SUPPORT

Pour questions/blocages:
1. Créer issue avec tag `performance/splash`
2. Inclure profiling data et traces
3. Mentionner device + connection (WiFi/3G/offline)

