# 📊 GUIDE DE MESURE - SPLASHSCREEN PERFORMANCE

Comment mesurer précisément les temps de démarrage et valider l'impact des optimisations.

---

## 🔍 INSTRUMENTATION - AJOUTER DES LOGS

### 1. Bootstrap Timeline

Ajouter dans `lib/main.dart`:

```dart
final _bootstrapTimeline = <String, DateTime>{};

Future<_BootResult> _bootstrap() async {
  final methodStart = DateTime.now();
  _bootstrapTimeline['start'] = methodStart;

  // 1) Firebase
  try {
    final firebaseStart = DateTime.now();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    _bootstrapTimeline['firebase'] = DateTime.now();
    _logDuration('Firebase', firebaseStart);
  } catch (e) {
    _bootstrapTimeline['firebase_error'] = DateTime.now();
    debugPrint('❌ Bootstrap: Firebase.initializeApp failed/timeout: $e');
  }

  // 2) Stripe
  if (!kIsWeb) {
    final stripeStart = DateTime.now();
    try {
      // ... Stripe code ...
      _bootstrapTimeline['stripe'] = DateTime.now();
      _logDuration('Stripe', stripeStart);
    } catch (e) {
      debugPrint('⚠️ Bootstrap: Stripe error: $e');
    }
  }

  // 3) Mapbox token
  final tokenStart = DateTime.now();
  try {
    await MapboxTokenService.warmUp().timeout(const Duration(seconds: 2));
    _bootstrapTimeline['mapbox_token'] = DateTime.now();
    _logDuration('MapboxToken', tokenStart);
  } catch (e) {
    debugPrint('⚠️ Bootstrap: MapboxTokenService error: $e');
  }

  // 4) Language
  final langStart = DateTime.now();
  try {
    await Get.putAsync(() => LanguageService().init())
        .timeout(const Duration(seconds: 2));
    _bootstrapTimeline['language'] = DateTime.now();
    _logDuration('Language', langStart);
  } catch (e) {
    debugPrint('⚠️ Bootstrap: LanguageService error: $e');
  }

  // Session
  final sessionStart = DateTime.now();
  final session = SessionController()..start();
  CartService.instance.start();
  NotificationsService.instance.start(navigatorKey: _rootNavigatorKey);
  _bootstrapTimeline['session'] = DateTime.now();
  _logDuration('Session', sessionStart);

  final methodEnd = DateTime.now();
  _bootstrapTimeline['total'] = methodEnd;
  _logDuration('TOTAL BOOTSTRAP', methodStart);

  // Afficher un résumé
  _printBootstrapSummary();

  return _BootResult(session: session);
}

void _logDuration(String label, DateTime start) {
  final duration = DateTime.now().difference(start).inMilliseconds;
  final color = duration > 1000 ? '🔴' : duration > 500 ? '🟠' : '🟢';
  debugPrint('$color ⏱️ $label: ${duration}ms');
}

void _printBootstrapSummary() {
  debugPrint('\n');
  debugPrint('╔════════════════════════════════════════╗');
  debugPrint('║       BOOTSTRAP TIMELINE SUMMARY       ║');
  debugPrint('╠════════════════════════════════════════╣');

  final start = _bootstrapTimeline['start']!;
  final entries = _bootstrapTimeline.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  for (final entry in entries) {
    if (entry.key == 'start') continue;
    final elapsed = entry.value.difference(start).inMilliseconds;
    final bar = '█' * ((elapsed / 10).ceil());
    debugPrint('║ ${entry.key.padRight(18)} ${elapsed.toString().padLeft(6)}ms $bar');
  }

  debugPrint('╚════════════════════════════════════════╝');
  debugPrint('\n');
}
```

---

### 2. Splash Wrapper Timeline

Ajouter dans `lib/pages/splash_wrapper_page.dart`:

```dart
class _SplashWrapperPageState extends State<SplashWrapperPage> {
  static const Duration _fadeDuration = Duration(milliseconds: 450);

  final bool _showHome = true;
  bool _mapReady = false;
  bool _mapSignalReady = false;
  bool _assetsReady = false;
  bool _didHideSplash = false;
  bool _showSplashOverlay = true;
  late DateTime _splashStartTime;
  
  // ✅ AJOUTER TIMELINE
  final Map<String, DateTime> _timeline = {};

  @override
  void initState() {
    super.initState();
    _splashStartTime = DateTime.now();
    _timeline['splash_start'] = _splashStartTime;
    debugPrint('🚀 SplashWrapperPage: initState at ${_splashStartTime}');

    mapReadyNotifier.addListener(_onMapReady);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timeline['first_frame'] = DateTime.now();
      _logSinceSplashStart('First frame rendered');
      _startAssetPreload();
    });

    final timeout = kIsWeb
        ? const Duration(seconds: 12)
        : const Duration(seconds: 10);
    
    Future.delayed(timeout, () {
      if (mounted && !_didHideSplash) {
        _timeline['timeout_forced'] = DateTime.now();
        _logSinceSplashStart('⚠️ TIMEOUT - forcing splash hide');
        _hideSplash(force: true);
      }
    });
  }

  void _onMapReady() {
    if (!mapReadyNotifier.value || _mapSignalReady) return;
    _mapSignalReady = true;
    _timeline['map_ready_signal'] = DateTime.now();
    _logSinceSplashStart('✅ Map ready signal received');
    _tryHideSplash();
  }

  Future<void> _startAssetPreload() async {
    final preloadStart = DateTime.now();
    final assets = await StartupPreloadService.collectSplashImageAssets();
    
    if (!mounted) return;
    _timeline['preload_assets_start'] = preloadStart;

    try {
      int imageCached = 0;
      for (final path in assets) {
        await precacheImage(AssetImage(path), context);
        imageCached++;
      }
      _timeline['preload_complete'] = DateTime.now();
      _logSinceSplashStart('✅ Preloaded $imageCached images in ${DateTime.now().difference(preloadStart).inMilliseconds}ms');
    } catch (e) {
      debugPrint('⚠️ Preload error: $e');
    }

    if (!mounted) return;
    _assetsReady = true;
    _tryHideSplash();
  }

  void _tryHideSplash() {
    if (_didHideSplash) return;
    if (!_mapSignalReady || !_assetsReady) {
      _logSinceSplashStart('⏳ Waiting: mapSignal=$_mapSignalReady, assets=$_assetsReady');
      return;
    }

    final elapsedMs = DateTime.now().difference(_splashStartTime).inMilliseconds;
    final remainingMs = 1800 - elapsedMs; // Délai minimum
    
    _timeline['hide_splash_trigger'] = DateTime.now();
    _logSinceSplashStart('✅ All ready! Elapsed: ${elapsedMs}ms, delay remaining: ${remainingMs}ms');

    if (remainingMs > 0) {
      debugPrint('⏳ SplashWrapperPage: attente délai minimum splash (${remainingMs}ms)');
      Future.delayed(Duration(milliseconds: remainingMs), () {
        if (mounted) _hideSplash();
      });
      return;
    }

    _hideSplash();
  }

  void _hideSplash({bool force = false}) {
    if (_didHideSplash) return;
    _didHideSplash = true;
    _timeline['splash_hide_start'] = DateTime.now();
    _logSinceSplashStart('🎬 Starting fade animation');

    setState(() {
      _mapReady = true;
      if (force) {
        _mapSignalReady = true;
        _assetsReady = true;
      }
    });

    Future.delayed(_fadeDuration, () {
      if (!mounted) return;
      _timeline['splash_fade_complete'] = DateTime.now();
      _logSinceSplashStart('✅ Splash hidden! Total: ${DateTime.now().difference(_splashStartTime).inMilliseconds}ms');
      
      setState(() {
        _showSplashOverlay = false;
      });

      // IMPRIMER RAPPORT FINAL
      _printSplashTimeline();
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        triggerWebViewportResize();
        Future.delayed(const Duration(milliseconds: 60), triggerWebViewportResize);
        Future.delayed(const Duration(milliseconds: 220), triggerWebViewportResize);
        Future.delayed(
          _fadeDuration + const Duration(milliseconds: 80),
          triggerWebViewportResize,
        );
      });
    }
  }

  void _logSinceSplashStart(String message) {
    final elapsed = DateTime.now().difference(_splashStartTime).inMilliseconds;
    debugPrint('  [${elapsed.toString().padLeft(5)}ms] $message');
  }

  void _printSplashTimeline() {
    debugPrint('\n');
    debugPrint('╔════════════════════════════════════════╗');
    debugPrint('║      SPLASH WRAPPER TIMELINE           ║');
    debugPrint('╠════════════════════════════════════════╣');

    final start = _splashStartTime;
    final entries = _timeline.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (final entry in entries) {
      final elapsed = entry.value.difference(start).inMilliseconds;
      final bar = '█' * ((elapsed / 50).ceil());
      debugPrint('║ ${entry.key.padRight(25)} ${elapsed.toString().padLeft(5)}ms $bar');
    }

    final total = DateTime.now().difference(start).inMilliseconds;
    debugPrint('╠════════════════════════════════════════╣');
    debugPrint('║ TOTAL SPLASH → INTERACTIVE: ${total.toString().padLeft(5)}ms');
    debugPrint('╚════════════════════════════════════════╝');
    debugPrint('\n');
  }

  // ... rest of the code ...
}
```

---

## 📱 PROFILING SUR DEVICE

### Android (via adb logcat)

```bash
# 1. Nettoyer logcat
adb logcat -c

# 2. Lancer app
adb shell am start -n com.example.maslive/.MainActivity

# 3. Capturer logs (garder la fenêtre ouverte)
adb logcat | grep -E "SplashWrapper|Bootstrap|Firebase|⏱️|✅|🎬|TIMELINE"

# Résultat attendu:
# 🚀 SplashWrapperPage: initState
# 🟢 ⏱️ Firebase: 250ms
# 🟢 ⏱️ MapboxToken: 50ms
# 🟢 ⏱️ Language: 100ms
# ...
# ✅ Splash hidden! Total: 2850ms
```

### iOS (via Xcode)

```
1. Xcode → Run app
2. Xcode → View → Debug Area → Console
3. Voir les mêmes logs que sur Android
```

### Web (DevTools)

```javascript
// Dans la console DevTools (F12):
// Les logs debugPrint() s'affichent dans Console

// Alternativement, utiliser Performance API:
performance.mark('splash-start');
// ... app startup ...
performance.mark('splash-end');
performance.measure('splash', 'splash-start', 'splash-end');
console.log(performance.getEntriesByName('splash')[0]);
```

---

## 📊 EXTRACTION DES MÉTRIQUES

### Script Python pour analyzer les logs

```python
import re
from datetime import datetime

def parse_splash_log(logfile):
    """Parse les logs et extrait les métrics"""
    
    timings = {}
    lines = []
    
    with open(logfile, 'r') as f:
        lines = f.readlines()
    
    # Chercher TIMELINE SUMMARY
    for i, line in enumerate(lines):
        if 'BOOTSTRAP TIMELINE SUMMARY' in line:
            # Parser bootstrap
            j = i + 3
            while j < len(lines) and '║' in lines[j]:
                match = re.search(r'(\w+)\s+(\d+)ms', lines[j])
                if match:
                    label, ms = match.groups()
                    timings[f'bootstrap_{label}'] = int(ms)
                j += 1
        
        if 'SPLASH WRAPPER TIMELINE' in line:
            # Parser splash
            j = i + 3
            while j < len(lines) and '║' in lines[j]:
                if 'TOTAL' in lines[j]:
                    match = re.search(r'(\d+)ms', lines[j])
                    if match:
                        timings['splash_total_ms'] = int(match.group(1))
                else:
                    match = re.search(r'(\w+)\s+(\d+)ms', lines[j])
                    if match:
                        label, ms = match.groups()
                        timings[f'splash_{label}'] = int(ms)
                j += 1
    
    return timings

# Utiliser:
# timings = parse_splash_log('app_startup.log')
# print(f"Bootstrap total: {timings.get('bootstrap_total', 'N/A')}ms")
# print(f"Splash total: {timings.get('splash_total_ms', 'N/A')}ms")
```

---

## 🎯 BASELINE RECORDING

### Créer un baseline AVANT optimisations

**Étapes**:
1. Effacer app data : `adb shell pm clear com.example.maslive`
2. Connexion : WiFi rapide + Device moderne
3. Lancer app 3 fois, garder les logs
4. Calculer moyenne

**Exemple de baseline**:
```
Device: Pixel 6 (moderne)
Network: WiFi 5GHz (rapide)
Build: Release

Run 1: 3,240ms
Run 2: 3,185ms
Run 3: 3,223ms
Average: 3,216ms
```

**Sauvegarder dans fichier**:
```
# BASELINE_SPLASH_PERFORMANCE.txt

Date: 2026-03-20
Device: Pixel 6 (Snapdragon 888)
Network: WiFi 5GHz
Build: Release
Condition: Cold start (app data cleared)

Metrics:
- Bootstrap total: 480ms
- Map ready signal: 1,520ms
- Preload assets: 750ms
- Splash total (bootstrap → interactive): 3,216ms

Components:
- Firebase: 240ms
- Mapbox token: 50ms
- Language: 100ms
- Session: 90ms
- Map init: 1,520ms (en arrière-plan)
- Preload: 750ms
- Fade: 450ms
- Delay minimum: 800ms
```

---

## 🔄 COMPARE APRÈS OPTIMISATIONS

Relancer les mêmes tests après chaque optimisation:

```
Date: 2026-03-25
Changes: 
  - Reduced splash delay 2500→1800ms
  - Parallelized bootstrap services

Metrics:
- Bootstrap total: 280ms (↓ 200ms, -42%)
- Map ready signal: 1,480ms (↓ 40ms, -3%)
- Preload assets: 450ms (↓ 300ms, -40%)
- Splash total: 2,680ms (↓ 536ms, -16%)

Breakdown:
- Firebase: 240ms (=)
- Mapbox token: 35ms (↓, parallelized)
- Language: 70ms (↓, parallelized)
- Session: 85ms (-)
- Map init: 1,480ms (-)
- Preload: 450ms (↓, tiering)
- Fade: 450ms (=)
- Delay minimum: 600ms (↓, reduced from 1800→1500ms)
```

---

## 📈 TRACKING DES AMÉLIORATIONS

### Excel/Sheets template

```
Date | Bootstrap | Map Ready | Preload | Splash Total | Changes
-----|-----------|-----------|---------|--------------|---------
3/20 | 480ms     | 1,520ms   | 750ms   | 3,216ms      | Baseline
3/25 | 280ms     | 1,480ms   | 450ms   | 2,680ms      | Parallelized, tiering
3/27 | 260ms     | 980ms     | 350ms   | 1,850ms      | Lazy-load services
4/01 | 250ms     | 850ms     | 300ms   | 1,600ms      | Firebase optimization
```

---

## 🚨 RED FLAGS

Surveiller ces métriques problématiques:

| Métric | Normal | Warning | Critical |
|--------|--------|---------|----------|
| Bootstrap total | <500ms | 500-1000ms | >1000ms |
| Map ready signal | <2000ms | 2-3s | >3s |
| Preload assets | <1000ms | 1-2s | >2s |
| Splash total | <3500ms | 3.5-5s | >5s |
| Fade animation | ~450ms | - | >1000ms |

---

## 🔗 FICHIERS RELATIFS

- `lib/main.dart` - Bootstrap instrumentation
- `lib/pages/splash_wrapper_page.dart` - Splash timeline
- `lib/pages/home_map_page_3d.dart` - Map performance
- `lib/services/startup_preload_service.dart` - Asset preload timing

---

**Next**: Après enregistrement du baseline, procéder aux optimisations Phase 1.

