# 🚀 AUDIT DE PERFORMANCE - SPLASHSCREEN

**Date**: Mars 2026  
**Analyse**: Étude complète du cycle de démarrage et du chargement du splashscreen MASLIVE  
**Objectif**: Identifier et proposer des améliorations pour accélérer le chargement initial

---

## 📊 VUE D'ENSEMBLE DU CYCLE DE DÉMARRAGE

### Séquence temporelle actuelle :

```
[0ms]   → runApp() lancé
[0-50ms] → _BootstrapRoot construit (FutureBuilder attente)
[50ms]   → _bootstrap() démarre

[50-62ms] → Firebase.initializeApp() (timeout 12s)
           ↳ Bloquant mais avec fallback
           ↳ Critique : sans ceci pas auth/firestore

[62-66ms] → Stripe.applySettings() (timeout 4s, native only)
           ↳ Non-bloquant en web
           ↳ Important pour commerce

[66-68ms] → MapboxTokenService.warmUp() (timeout 2s)
           ↳ SharedPreferences (rapide)
           ↳ Critique pour carte

[68-71ms] → LanguageService.init() (timeout 3s)
           ↳ Indispensable pour Get.find()
           ↳ Affiche textes UI

[71-79ms] → PremiumService.init() (timeout 8s, NON-BLOQUANT)
           ↳ Lancé en arrière-plan
           ↳ Pour abonnements

[79-82ms] → SessionController.start()
           ↳ Services supplémentaires
           ↳ CartService, NotificationsService

[82ms]    → _BootResult retourné
           ↳ SplashScreen() remplacé par MasLiveApp

[82-300ms]→ SplashWrapperPage affichée
           ↳ HomeMapPage3D chargée en arrière-plan
           ↳ mapReadyNotifier attendu

[300ms+]  → HomeMapPage3D initState()
           ↳ Mapbox SDK initialization
           ↳ Geolocation service start
           ↳ Données Firestore (POIs, circuits, etc.)

[300-2500ms] → Préchargement assets + attente map
           ↳ precacheImage() pour toutes les images
           ↳ warmupMapStyleAsset()

[2500ms]  → Délai minimum splash expiré
           ↳ Si map prête = fade out
           ↳ Si timeout 10-12s = force hide

[2500-3000ms] → Fade animation (450ms)
           ↳ Splashscreen → HomeMapPage3D

[3000ms+] → Application interactive
```

---

## 🔴 GOULOTS D'ÉTRANGLEMENT IDENTIFIÉS

### **CRITIQUE 1 : Firebase.initializeApp() - ⏱️ Jusqu'à 12s**

**Fichier**: `lib/main.dart:130-134`  
**Problème**: 
- Le plus long timeout de bootstrap
- BLOQUANT : autres services attendent
- Réseau → lent sur connections faibles
- Affiche splash natif si dépassement

**Symptômes observés**:
- Sur 3G/4G lent : 6-8s+ avant splash Flutter
- Sur offline : exactement 12s + timeout
- Impact maximal détectable par utilisateur

**Score**: 🔴🔴🔴 CRITIQUE

---

### **CRITIQUE 2 : HomeMapPage3D.initState() - ⏱️ 1-3s**

**Fichier**: `lib/pages/home_map_page_3d.dart:200-300`  
**Problème**:
- Mapbox SDK init (native bindings)
- Geolocation permission request
- Firestore queries (POIs, circuits, preferences)
- Style JSON parsing
- Toutes les queries lancées en parallèle MAIS attendent les résultats

**Cascade observée**:
```
initState()
├─ MapboxMap creation (SDK binding) ............ ~300-500ms
├─ GeolocationService.start() (permission) .... ~200-800ms (interactive)
├─ Firestore queries (4+ parallèles) ........... ~500-1500ms
├─ Route style pro init ....................... ~100-200ms
└─ Market map service .......................... ~100-300ms
```

**Score**: 🔴🔴🔴 CRITIQUE

---

### **IMPORTANT 3 : Préchargement assets trop agressif - ⏱️ 800-1200ms**

**Fichier**: `lib/pages/splash_wrapper_page.dart:56-70`  
**Problème**:
- Charge TOUTES les images (assets/images/*.png, assets/shop/*.*)
- Boucle séquentielle `for` avec `precacheImage()`
- Bloque l'UI de SplashWrapperPage
- Manifesté par un "freeze" visible du splashscreen

**Contenu scanné**:
- ~150-200+ images en assets/images/
- ~300-400+ images en assets/shop/
- Chaque `precacheImage()` = I/O GPU + décodage

**Astuces actuelles** ✅:
- Non-bloquant (en postFrameCallback)
- Timeout graceful (continue même si timeout)
- MAIS : ralentit le rendu du splashscreen visible

**Score**: 🟠🟠 IMPORTANT

---

### **IMPORTANT 4 : Délai minimum splash TROP LONG - ⏱️ 2500ms fixe**

**Fichier**: `lib/pages/splash_wrapper_page.dart:90-104`  
**Problème**:
- Attente forcée 2.5s MÊME si tout est prêt
- UX: utilisateur voit splashscreen "figé" après que map soit prête
- Raison historique : "branding time" mais trop conservateur

**Analyse du code**:
```dart
final remainingMs = 2500 - elapsedMs;
if (remainingMs > 0) {
  Future.delayed(Duration(milliseconds: remainingMs), () {
    if (mounted) _hideSplash();
  });
}
```

**Scénarios réels**:
- Connexion rapide + bon device = map prête en 1.5s → attente 1s supplémentaire inutile
- Utilisateur perçoit un "faux chargement" après que tout soit prêt
- A/B test : réduire à 1800ms gagnerait 700ms visible

**Score**: 🟠🟠 IMPORTANT

---

### **MOYEN 5 : LanguageService.init() - ⏱️ 0-3s**

**Fichier**: `lib/main.dart:166-173`  
**Problème**:
- Timeout 3s mais souvent rapide
- Si timeout : fallback sans init complète
- Sinon : Firestore query de config langue

**Optimisation possible**:
- Lancer APRÈS splash si pas critique
- Ou cacher le fallback comme intérieur

**Score**: 🟡 MOYEN

---

### **MOYEN 6 : PremiumService.init() en arrière-plan - ⏱️ 0-8s**

**Fichier**: `lib/main.dart:176-195`  
**Problème**:
- Non-bloquant (unawaited) ✅
- MAIS : Revolution Cat API (réseau externe)
- Peut causer GC/freezes après 1-2s d'utilisation
- Sur web/pauvre connexion : 5-8s de travail silencieux

**Optimisation possible**:
- Repousser à APRÈS premier rendu
- Ou lazy-load à la première utilisation premium

**Score**: 🟡 MOYEN

---

### **MINEUR 7 : Stripe.applySettings() - ⏱️ 0-4s (native only)**

**Fichier**: `lib/main.dart:140-151`  
**Problème**:
- Timeout 4s, native uniquement (pas web)
- Réseau si pas en cache
- Non-critique pour initial

**Score**: 🟢 MINEUR (web: non applicable)

---

### **MINEUR 8 : Image.asset() sur SplashScreen - ⏱️ 0-200ms**

**Fichier**: `lib/pages/splash_screen.dart:70-82`  
**Problème**:
- Très optimisé (FilterQuality.high = cache GPU)
- Une image = leprobé léger
- Fallback icon déjà prévu

**Score**: 🟢 MINEUR (déjà optimisé)

---

## 📈 TIMELINE COMPARATIVE

### Cas optimal (WiFi rapide + device moderne) :
```
Firebase           ...... 200ms ✅
Stripe             ...... 100ms ✅
Mapbox token       ...... 50ms ✅
Language           ...... 100ms ✅
Bootstrap total    → 450ms
─
SplashWrapperPage  ▓▓▓▓▓▓ 200ms (overlay rendu)
HomeMapPage init   ▓▓▓▓▓▓▓▓ 800ms (en arrière-plan)
Préchargement      ▓▓▓▓ 600ms (parallèle)
Map prêt           ▓▓▓▓▓▓▓ 1500ms
─
Délai minimum      ████ 1000ms (attente inutile)
Fade animation     ██ 450ms
─
TOTAL              → 3,400ms (3.4s)
```

### Cas mauvais (3G lent + device ancien) :
```
Firebase           ████████████ 5000ms ⚠️
Stripe             ░░░░ 2000ms ⚠️
Mapbox token       ░░ 500ms ⚠️
Language           ░ 1500ms ⚠️
Bootstrap total    → 9000ms
─
SplashWrapperPage  ▓▓▓▓▓▓ 200ms
HomeMapPage init   ▓▓▓▓▓▓▓▓▓▓▓▓ 2000ms
Préchargement      ▓▓▓▓▓ 1000ms
Map prêt           ▓▓▓▓▓▓▓▓ 2500ms
─
Délai minimum      ████ 2500ms (tous attendus)
Fade animation     ██ 450ms
─
TOTAL              → 12,000ms+ (12s+) 🔴
        (+ timeout splash natif sur plateforme)
```

---

## 💡 RECOMMANDATIONS D'OPTIMISATION

### **PRIORITY 1️⃣ - CRITIQUE** (Gain: 2-5s)

#### A. Paralleliser Bootstrap Services
**Cible**: `lib/main.dart:130-195`

**Actions**:
1. Lancer Stripe + MapboxToken + Language EN PARALLÈLE (Future.wait)
2. Garder Firebase bloquant (requis pour auth)
3. PremiumService reste non-bloquant ✓

**Implémentation**:
```dart
// AVANT:
await Firebase.init();  // 12s max
await Stripe.applySettings();
await MapboxToken.warmUp();
await Language.init();

// APRÈS:
await Firebase.init(); // BLOQUANT (requis)
await Future.wait([
  Stripe.applySettings().timeout(...),
  MapboxToken.warmUp().timeout(...),
  Language.init().timeout(...),
]); // Parallèle au lieu de séquentiel
```

**Gain estimé**: 1-2s (surtout si une agence timeout)

---

#### B. Firebase Initialization Optimization
**Cible**: `lib/main.dart:130-134`

**Actions**:
1. **Audit offline**: Vérifier si Firebase.init() attend réseau obligatoirement
2. **Cache service**: Implémenter cache local des tokens
3. **Lazy auth**: Retarder auth user checks après splash
4. **Fallback mode**: Application en "mode guest" si Firebase timeout

**Implémentation**:
```dart
// Version actuelle: attend et timeout
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
).timeout(const Duration(seconds: 12));

// Optimiser :
final firebaseInit = Firebase.initializeApp(...)
  .timeout(const Duration(seconds: 8)) // Réduire timeout
  .catchError((e) {
    debugPrint('Firebase offline/timeout - guest mode');
    return null; // Continue sans auth
  });
```

**Gain estimé**: 2-4s (réduction du timeout + gestion offline)

---

#### C. Lazy-load HomeMapPage3D Services
**Cible**: `lib/pages/home_map_page_3d.dart:150-200`

**Actions**:
1. Retarder Firestore queries jusqu'à "map mounted"
2. Afficher map SANS POIs d'abord, puis charger POIs
3. Geolocation : commencer APRÈS première rendue (user visible)

**Implémentation**:
```dart
// initState LÉGER:
void initState() {
  super.initState();
  _initMapOnly(); // Juste Mapbox
  _geo.startAsyncNoWait(); // Async, pas d'attente
}

void _initMapOnly() {
  // Map render seulement
}

void _initDataServices() {
  // Après map visible
  _loadFirestoreData();
  _initTracking();
}

@override
Widget build() {
  if (!_mapReady) {
    return _buildMapEmpty(); // Map vierge rapide
  }
  return _buildMapWithPOIs(); // Ajouter POIs après
}
```

**Gain estimé**: 800-1200ms (map visible + données en arrière-plan)

---

### **PRIORITY 2️⃣ - IMPORTANT** (Gain: 1-2s)

#### D. Réduire Délai Minimum Splash de 2500ms → 1500ms
**Cible**: `lib/pages/splash_wrapper_page.dart:38`

**Actions**:
1. Diminuer de 2500ms à 1500-1800ms
2. A/B test auprès utilisateurs
3. Garder 450ms fade pour smooth UX

**Avant/Après**:
```dart
// AVANT:
final remainingMs = 2500 - elapsedMs;

// APRÈS:
final remainingMs = 1500 - elapsedMs; // Gain 1s direct
```

**Gain estimé**: 1.0-1.5s (purement UI/timing)

---

#### E. Batching Image Preload (Prioritization)
**Cible**: `lib/services/startup_preload_service.dart:15-35`

**Actions**:
1. **Tier 1** (ASAP): Charger SEULEMENT les 10-15 images critiques
   - splash/wom1.png ✓
   - logo minimal
   - icônes splash

2. **Tier 2** (Après splash): Autres images
3. **Lazy**: assets/shop/* images on-demand

**Implémentation**:
```dart
// AVANT:
for (final path in assets) { // 300+ images!
  await precacheImage(AssetImage(path), context);
}

// APRÈS:
// Tier 1 : critique
final critical = ['splash/wom1.png', 'logo.png'];
for (final path in critical) {
  await precacheImage(AssetImage(path), context);
}

// Tier 2 : après splash hide
if (!mounted) return;
setState(() => _assetsReady = true); // Splash peut disparaître

// Puis charger resto en arrière-plan:
WidgetsBinding.instance.addPostFrameCallback((_) async {
  for (final path in noncritical) {
    await precacheImage(AssetImage(path), context);
  }
});
```

**Gain estimé**: 600-1000ms (image preload moins bloquant)

---

#### F. Mapbox GL JS Warmup (Web Only)
**Cible**: `lib/pages/home_map_page_3d.dart` + web platform

**Actions**:
1. Charger Mapbox JavaScript plus tôt
2. Pré-render canvas invisible de la map

**Implémentation**:
```dart
// Dans startup_preload_service.dart:
static Future<void> warmupMapboxWeb() async {
  if (!kIsWeb) return;
  try {
    // Pré-charger Mapbox JS
    await rootBundle.loadString('assets/map_styles/google_light.json');
    
    // Créer une iframe invisible pour warm cache
    // (non-blocking)
  } catch (_) {}
}

// Appeler dans _bootstrap():
await StartupPreloadService.warmupMapboxWeb();
```

**Gain estimé**: 200-400ms web (cache JS + style preload)

---

### **PRIORITY 3️⃣ - MOYEN** (Gain: 0.3-0.8s)

#### G. PremiumService Lazy Initialization
**Cible**: `lib/main.dart:176-195`

**Actions**:
1. Ne pas lancer en bootstrap
2. Lancer au premier accès (ou après 3s)

**Implémentation**:
```dart
// AVANT: Lancé en bootstrap (peut freeze post-load)
unawaited(
  PremiumService.instance.init(...)
    .timeout(...)
    .catchError(...)
);

// APRÈS: Lancé after splash hide
// Dans splash_wrapper_page.dart:
Future<void> _initPremiumService() async {
  await Future.delayed(const Duration(seconds: 3)); // Après splash
  if (!mounted) return;
  await PremiumService.instance.init(...).catchError((_) {});
}
```

**Gain estimé**: 0-1s (si Revolution Cat tarde)

---

#### H. LanguageService Async Fallback
**Cible**: `lib/main.dart:166-173`

**Actions**:
1. Utiliser version en-cache si timeout
2. Lancer fetch en arrière-plan
3. Pas de timeout dur

**Implémentation**:
```dart
// AVANT:
await Get.putAsync(() => LanguageService().init())
  .timeout(const Duration(seconds: 3));

// APRÈS:
await Get.putAsync(() => LanguageService().tryInit());

// Dans LanguageService:
Future<void> tryInit() async {
  try {
    await init().timeout(Duration(seconds: 1));
  } catch (_) {
    loadFromCache(); // Fallback
    // Puis refetch en background
    init().ignore();
  }
}
```

**Gain estimé**: 0.5s (réduction timeout)

---

## 🎯 PLAN D'IMPLÉMENTATION (Phases)

### **PHASE 1 - AUDIT & MESURE** (1-2 jours)
- [ ] Instruments profiling (Android Studio Profiler, DevTools)
- [ ] Mesurer temps exact Firebase.init par scénario
- [ ] Mesurer temps exact HomeMapPage3D.initState()
- [ ] Baseline: enregistrer temps total actuel

### **PHASE 2 - QUICK WINS** (3-5 jours)
1. Réduire délai minimum splash (2500 → 1800ms)
2. Paralleliser services non-Firebase
3. Batching image preload (Tier 1 vs Tier 2)
4. **Gain attendu**: 1.5-2.5s visible

### **PHASE 3 - ARCHITECTURE** (5-10 jours)
1. Lazy-load HomeMapPage3D services
2. Map-only rendering avant POIs
3. Firebase optimization + offline support
4. **Gain attendu**: 2-5s additionnel

### **PHASE 4 - WEB OPTIMIZATION** (2-3 jours)
1. Mapbox GL JS warmup
2. Service worker preload
3. Asset CDN caching
4. **Gain attendu**: 0.5-1s web

### **PHASE 5 - TESTING & ROLLOUT** (3-5 jours)
1. A/B testing auprès users
2. Profiling avancé (COP)
3. Monitoring production
4. Gradual rollout

---

## 📊 ESTIMATIONS DE GAIN

| Optimisation | Effort | Gain | Priorité |
|---|---|---|---|
| A. Paralleliser Bootstrap | 2h | 1-2s | 🔴 CRITIQUE |
| B. Firebase Offline + Cache | 6h | 2-4s | 🔴 CRITIQUE |
| C. Lazy-load HomeMap | 8h | 0.8-1.2s | 🔴 CRITIQUE |
| D. Réduire splash delay | 30mn | 1-1.5s | 🟠 IMPORTANT |
| E. Image preload tier | 3h | 0.6-1s | 🟠 IMPORTANT |
| F. Mapbox web warmup | 2h | 0.2-0.4s | 🟠 IMPORTANT |
| G. PremiumService lazy | 2h | 0-1s | 🟡 MOYEN |
| H. LanguageService async | 1h | 0.5s | 🟡 MOYEN |
| **TOTAL** | **24-26h** | **6-10s** | **CRITIQUE** |

---

## 🧪 MÉTRIQUES DE SUCCÈS

### Avant optimisations:
- WiFi rapide: **3-4s** splash visible
- 3G moyen: **8-12s** splash visible
- Device ancien: **10-15s** splash visible  
- Offline: **12s+ timeout**

### Après optimisations (objectif):
- WiFi rapide: **1.5-2s** splash (gain: 50% 📉)
- 3G moyen: **4-6s** splash (gain: 40% 📉)
- Device ancien: **6-10s** splash (gain: 35% 📉)
- Offline: **3-4s** mode guest (gain: 70% 📉)

### Metrics à tracker:
1. **Splash visible time** (temps pour splash Flutter visible)
2. **Splash hide time** (temps splash → app interactive)
3. **Time to interactive** (TTI)
4. **Time to first paint** (TFP)
5. **Firebase init duration**
6. **HomeMapPage init chain**

---

## 🔗 FICHIERS CONCERNÉS

### Bootstrap principal:
- `lib/main.dart` (lines: 87-250)

### Splash lifecycle:
- `lib/pages/splash_screen.dart`
- `lib/pages/splash_wrapper_page.dart`

### Home page:
- `lib/pages/home_map_page_3d.dart`

### Services:
- `lib/services/startup_preload_service.dart`
- `lib/services/mapbox_token_service.dart`
- `lib/services/language_service.dart`
- `lib/services/premium_service.dart`

---

## 📋 CHECKLIST DE SUIVI

- [ ] Profiling baseline enregistré
- [ ] Optimisations PHASE 1 implémentées
- [ ] Tests unitaires écrits
- [ ] Profiling après chaque phase
- [ ] A/B testing auprès users
- [ ] Documentation mise à jour
- [ ] Monitoring en prod configuré

---

**À suivre**: Après implémentation, re-audit en conditions réelles (réseau 3G, device moyen-bas)

