# 🚀 COMMANDES DÉPLOIEMENT - SYSTÈME TRACKING GROUPE

## Étape 1: Vérifier et déployer Cloud Functions

```bash
# Aller dans dossier functions
cd /workspaces/MASLIVE/functions

# Vérifier que group_tracking.js est exporté dans index.js
cat index.js | grep "group_tracking"

# Si absent, ajouter cette ligne dans index.js:
# exports.calculateGroupAveragePosition = require('./group_tracking').calculateGroupAveragePosition;

# Déployer Cloud Function
firebase deploy --only functions:calculateGroupAveragePosition

# Vérifier déploiement
firebase functions:log --only calculateGroupAveragePosition
```

---

## Étape 2: Vérifier et déployer Firestore Rules

```bash
# Vérifier syntaxe firestore.rules
cd /workspaces/MASLIVE

# Vérifier que les collections group_* existent dans firestore.rules
cat firestore.rules | grep "match /group_"

# Déployer rules
firebase deploy --only firestore:rules

# Tester avec emulator
firebase emulators:start
```

**Expected output**:
```
✔  Firestore Rules deployed
```

---

## Étape 3: Vérifier et déployer Storage Rules

```bash
# Vérifier Storage Rules contiennent group_shops
cat storage.rules | grep "group_shops"

# Déployer
firebase deploy --only storage

# Expected output:
# ✔  Storage Rules deployed
```

---

## Étape 4: Vérifier permissions Android/iOS

```bash
# Android
cat app/android/app/src/main/AndroidManifest.xml | grep "ACCESS_.*_LOCATION"

# Si absent, ajouter:
# <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
# <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

# iOS
cat app/ios/Runner/Info.plist | grep "NSLocation"

# Si absent, ajouter:
# <key>NSLocationWhenInUseUsageDescription</key>
# <string>Localisation pour tracking de groupe</string>
```

---

## Étape 5: Vérifier pubspec.yaml dépendances

```bash
cd /workspaces/MASLIVE/app

# Vérifier dépendances présentes
grep -E "geolocator|fl_chart|firebase_auth|cloud_firestore|firebase_storage" pubspec.yaml

# Si absent, ajouter dans pubspec.yaml:
# geolocator: ^11.0.0
# fl_chart: ^0.70.0
# firebase_auth: ^5.7.0
# cloud_firestore: ^5.6.0
# firebase_storage: ^12.4.0
# firebase_functions: ^2.0.0

# Mettre à jour
flutter pub get
```

---

## Étape 6: Ajouter routes dans main.dart

```bash
# Vérifier que routes existent
cat app/lib/main.dart | grep "/group/admin"

# Si absent, ajouter dans GetMaterialApp routes:
```

```dart
import 'pages/group/admin_group_dashboard_page.dart';
import 'pages/group/tracker_group_profile_page.dart';
import 'pages/group/group_map_live_page.dart';
import 'pages/group/group_track_history_page.dart';
import 'pages/group/group_export_page.dart';

// Dans routes:
'/group/admin': (context) => const AdminGroupDashboardPage(),
'/group/tracker': (context) => const TrackerGroupProfilePage(),
'/group/map': (context) => const GroupMapLivePage(),
'/group/history': (context) => const GroupTrackHistoryPage(),
'/group/export': (context) => const GroupExportPage(),
```

---

## Étape 7: Compiler et vérifier

```bash
cd /workspaces/MASLIVE/app

# Analyzer
flutter analyze

# Expected: No errors

# Pub get
flutter pub get

# Build web (si web support needed)
flutter build web --release

# Expected: Built successfully
```

---

## Étape 8: Tests sur device

```bash
# Android
flutter run -d <device-id>

# iOS
flutter run -d <device-id>

# Web
flutter run -d web
```

**Test checklist**:
```
[ ] App démarre sans erreur
[ ] Menu visible
[ ] Routes /group/* fonctionnent
[ ] Admin peut créer profil (code 6 chiffres généré)
[ ] Tracker peut se rattacher
[ ] GPS permission s'affiche
[ ] Tracking démarre/arrête
[ ] Position moyenne s'affiche dans Carte Live
```

---

## Étape 9: Vérifier Firestore après tests

```bash
# Vérifier collections créées
Firebase Console → Firestore Database

Collections attendues:
✓ group_admin_codes/{code}
✓ group_admins/{uid}
✓ group_trackers/{uid}
✓ group_positions/{code}/members/{uid}
✓ group_tracks/{code}/sessions/{id}
✓ group_tracks/{code}/sessions/{id}/points/{pointId}
✓ group_shops/{code}/products/{id}
✓ group_shops/{code}/media/{id}
```

---

## Étape 10: Vérifier Cloud Function logs

```bash
firebase functions:log --only calculateGroupAveragePosition

# Expected logs:
# Calcul position moyenne pour groupe: 123456
# Aucun membre trouvé
# Ou:
# Position moyenne calculée: 48.8570, 2.3525
# Position moyenne mise à jour avec succès
```

---

## Étape 11: Full deployment

```bash
# Depuis root /workspaces/MASLIVE
firebase deploy

# Ou sélectivement:
firebase deploy --only functions,firestore:rules,storage
```

**Expected output**:
```
✔ Deploy complete!

Project Console: https://console.firebase.google.com/project/maslive/overview
Hosting URL: https://maslive.web.app
```

---

## Dépannage

### Cloud Function ne s'exécute pas

```bash
# Vérifier logs
firebase functions:log --only calculateGroupAveragePosition

# Vérifier trigger
# Doit être: group_positions/{adminGroupId}/members/{uid}

# Vérifier que group_positions est écrite
# Admin ou Tracker démarre tracking
# Puis checker Firestore group_positions/{code}/members/{uid}
```

### Firestore Rules bloquent

```bash
# Vérifier erreur dans console
# Firebase Console → Cloud Firestore → Rules

# Tester avec emulator
firebase emulators:start

# Puis app en dev mode
# Vérifier règles permettent write/read correctes
```

### Permissions GPS refusées

```bash
# Android
Settings → Apps → MASLIVE → Permissions → Location → Allow

# iOS
Settings → MASLIVE → Location → While Using the App

# Puis tester nouveau
```

### Carte Live ne montre pas marqueur

```bash
# Vérifier
1. averagePosition est calculée dans Firestore
2. Carte selectedMapId sélectionnée
3. Stream streamAveragePosition() retourne données
4. Mapbox/FlutterMap configurés correctement
```

---

## Commands rapides

```bash
# Déployer tout
cd /workspaces/MASLIVE && firebase deploy

# Logs Cloud Function
firebase functions:log --only calculateGroupAveragePosition

# Firestore emulator
firebase emulators:start

# Build Flutter web
flutter build web --release

# Compiler et vérifier
flutter analyze && flutter pub get
```

---

**Generated**: 2026-02-04  
**By**: GitHub Copilot
