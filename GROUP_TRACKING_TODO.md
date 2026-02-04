# 🎯 RÉSUMÉ SYSTÈME TRACKING GROUPE - OK / À FAIRE

## ✅ CE QUI EST COMPLÈTEMENT FAIT

### 📦 Modèles Dart (17 fichiers)
```
✅ group_admin.dart
   ├─ GroupAdmin (code 6 chiffres, visibilité, position)
   ├─ GeoPosition (lat, lng, alt, accuracy, timestamp)
   └─ GroupAdminCode (lookup rapide)

✅ group_tracker.dart
   ├─ GroupTracker (rattaché, linkedAdminUid)
   └─ Méthodes toFirestore/fromFirestore

✅ track_session.dart
   ├─ TrackSession (startedAt, endedAt, summary)
   ├─ TrackSummary (durée, distance, dénivelé)
   └─ TrackPoint (lat, lng, alt, accuracy, timestamp)

✅ group_product.dart
   └─ GroupShopProduct (titre, prix, stock, photos)

✅ group_media.dart
   └─ GroupMedia (url, type, tags, isVisible)
```

### 🔧 Services (8 fichiers)
```
✅ group_link_service.dart
   ├─ createAdminProfile() - Génère code 6 chiffres unique
   ├─ linkTrackerToAdmin() - Valide code + rattache
   ├─ validateAdminCode() - Lookup rapide
   └─ changeTrackerGroup() - Action "Changer de groupe"

✅ group_tracking_service.dart
   ├─ startTracking() - Lance GPS 5m
   ├─ stopTracking() - Arrête + calcul résumé
   ├─ _handleNewPosition() - Write Firestore
   └─ _calculateSummary() - Distance/dénivelé/vitesse

✅ group_average_service.dart
   ├─ streamAveragePosition() - Écoute Firestore
   └─ calculateAveragePositionClient() - Fallback client

✅ group_export_service.dart
   ├─ generateCSV() - Format CSV complet
   ├─ generateJSON() - Format JSON
   └─ _calculateStatistics() - Durée, distance, dénivelé

✅ group_shop_service.dart
   ├─ addProduct() - CRUD produits
   ├─ addMedia() - CRUD médias
   ├─ uploadPhotoToStorage() - Storage upload
   └─ updateStock() - Stock synchronisé

✅ group_download.dart / group_download_web.dart / group_download_stub.dart
   └─ Cross-platform export (mobile + web)
```

### 🎨 Pages UI (5 fichiers)
```
✅ admin_group_dashboard_page.dart
   ├─ Affichage code 6 chiffres
   ├─ Liste trackers rattachés
   ├─ Toggle "Visibilité Groupe"
   ├─ Dropdown sélection carte
   ├─ Bouton "Démarrer/Arrêter tracking"
   ├─ Bouton "Historique"
   ├─ Bouton "Exports"
   ├─ Bouton "Boutique"
   ├─ Bouton "Médias"
   └─ Bouton "Stats" (bar chart)

✅ tracker_group_profile_page.dart
   ├─ Champ saisie code 6 chiffres
   ├─ Affichage statut lié/non-lié
   ├─ Bouton "Se rattacher"
   ├─ Action "Changer de groupe"
   ├─ Bouton "Démarrer/Arrêter tracking"
   ├─ Bouton "Historique"
   └─ Bouton "Exports"

✅ group_map_live_page.dart
   ├─ Affiche carte sélectionnée (selectedMapId)
   ├─ Marqueur unique position moyenne (averagePosition)
   └─ Actualisation temps réel via Stream

✅ group_track_history_page.dart
   ├─ Liste des sessions
   ├─ Détails session (durée, distance, dénivelé)
   └─ Édition session

✅ group_export_page.dart
   ├─ Bouton Export CSV
   ├─ Bouton Export JSON
   └─ Share / Download cross-platform
```

### 📊 Widgets (1 fichier)
```
✅ group_stats_bar_chart.dart
   ├─ Bar chart FL_CHART
   ├─ Distance (km) par jour/session
   └─ Durée (min) par jour/session
```

### ☁️ Cloud Functions (1 fichier)
```
✅ functions/group_tracking.js
   ├─ Trigger: group_positions/{adminGroupId}/members/{uid}
   ├─ Filtre positions valides (< 20s, accuracy < 50m)
   ├─ Calcule moyenne (lat, lng, alt)
   └─ Write averagePosition dans group_admins/{adminUid}
```

### 🗄️ Firestore Structure
```
✅ /group_admin_codes/{code}
   ├─ adminUid
   ├─ createdAt
   └─ isActive

✅ /group_admins/{uid}
   ├─ adminGroupId
   ├─ displayName
   ├─ isVisible (toggle)
   ├─ selectedMapId (dropdown)
   ├─ lastPosition
   ├─ averagePosition (calculé CF)
   └─ timestamps

✅ /group_trackers/{uid}
   ├─ adminGroupId
   ├─ linkedAdminUid
   ├─ displayName
   ├─ lastPosition
   └─ timestamps

✅ /group_positions/{code}/members/{uid}
   ├─ role
   ├─ lastPosition
   └─ updatedAt

✅ /group_tracks/{code}/sessions/{id}
   ├─ uid, role
   ├─ startedAt, endedAt
   ├─ summary {durationSec, distanceM, ascentM, descentM, avgSpeedMps}
   └─ /points/{pointId} [sub-collection]

✅ /group_shops/{code}/products/{id}
   ├─ title, description, price, stock
   ├─ photos[]
   ├─ isVisible
   └─ timestamps

✅ /group_shops/{code}/media/{id}
   ├─ url, type
   ├─ tags{}
   ├─ isVisible
   └─ createdAt
```

### 🔐 Firestore Rules
```
✅ Permissions granulaires implémentées
   ├─ Admin: lecture/écriture tout adminGroupId
   ├─ Tracker: lecture averagePosition si visible
   ├─ Chacun: écriture propres positions/sessions
   └─ Boutique: lecture selon isVisible
```

---

## ⚠️ CE QUI RESTE À FAIRE

### 1️⃣ **INTÉGRATION ROUTES** (Priorité HAUTE)
**What**: Ajouter routes dans navigation principale

**Where**: 
- `lib/main.dart` (routes GetX/Named)
- Menu navigation principal

**How**:
```dart
// À ajouter dans routes
'/group/admin': (context) => const AdminGroupDashboardPage(),
'/group/tracker': (context) => const TrackerGroupProfilePage(),
'/group/map': (context) => const GroupMapLivePage(),
'/group/history': (context) => const GroupTrackHistoryPage(),
'/group/export': (context) => const GroupExportPage(),

// À ajouter dans menu
ListTile(
  leading: const Icon(Icons.groups),
  title: const Text('Tracking Groupe'),
  onTap: () {
    // Déterminer admin vs tracker
    // Navigator.pushNamed(context, '/group/admin'); 
  },
)
```

**Test**:
```bash
# Vérifier routes
- App démarre
- Menu visible
- Navigation fonctionne
```

---

### 2️⃣ **CLOUD FUNCTION - DÉPLOIEMENT** (Priorité HAUTE)
**What**: Vérifier Cloud Function déployée et fonctionnelle

**Where**: `/functions/group_tracking.js` ou intégré dans `/functions/index.js`

**How**:
```bash
# Déployer
firebase deploy --only functions:calculateGroupAveragePosition

# Tester
firebase functions:log --only calculateGroupAveragePosition

# Vérifier dans Firestore
# group_admins/{uid}.averagePosition doit se remplir
```

**Test**:
```bash
# 1. Créer admin (code 123456, uid abc123)
# 2. Tracker démarre GPS → écrit dans group_positions/123456/members/{uid}
# 3. Cloud Function s'exécute
# 4. Vérifier group_admins/abc123.averagePosition mis à jour
```

---

### 3️⃣ **FIRESTORE RULES - DÉPLOIEMENT** (Priorité HAUTE)
**What**: Vérifier et déployer règles Firestore

**Where**: `/firestore.rules` (sections `group_*`)

**How**:
```bash
# Déployer
firebase deploy --only firestore:rules

# Tester
firebase emulators:start  # Firestore emulator
```

**Vérifications**:
- [ ] Admin peut lire/écrire adminGroupId
- [ ] Tracker peut lire averagePosition si visible
- [ ] Tracker ne peut pas lire données autres trackers
- [ ] Boutique readonly si non visible

**Test**:
```bash
# Cas 1: Tracker lié Admin1 ne doit pas voir données Admin2
# Cas 2: Admin masque groupe → Tracker ne voit plus average
# Cas 3: Admin peut voir ses produits boutique
```

---

### 4️⃣ **STORAGE RULES - DÉPLOIEMENT** (Priorité MOYENNE)
**What**: Vérifier Storage Rules pour uploads boutique

**Where**: `/storage.rules` (sections `group_shops`)

**How**:
```bash
# Vérifier path
storage.googleapis.com/maslive
└─ group_shops/{adminGroupId}/photos/{filename}

# Règles à vérifier
- Admin peut upload dans son adminGroupId
- Tracker ne peut pas upload
```

**Test**:
```bash
# Admin tente upload photo → OK
# Tracker tente upload → Refusé
```

---

### 5️⃣ **PERMISSIONS GPS** (Priorité HAUTE)
**What**: Vérifier permissions Android/iOS

**Where**: 
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

**How**:
```xml
<!-- Android -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- iOS -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Localisation pour tracking de groupe</string>
```

**Test**:
```bash
# Device/Emulator
# App → Tracking Groupe → Démarrer → Autoriser localisation
# Vérifier que position est écrite dans Firestore
```

---

### 6️⃣ **CARTE LIVE - INTÉGRATION** (Priorité MOYENNE)
**What**: Vérifier affichage marqueur averagePosition sur Mapbox

**Where**: `/lib/pages/group/group_map_live_page.dart`

**How**:
```dart
// Vérifier code affiche marqueur correctement
StreamBuilder<GeoPosition?>(
  stream: _averageService.streamAveragePosition(_admin!.adminGroupId),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data != null) {
      // Ajouter marqueur unique
      final pos = snapshot.data!;
      // Afficher marker à (pos.lat, pos.lng)
    }
  }
)
```

**Test**:
```bash
# Admin sélectionne carte → Ouvrir Carte Live
# 2+ membres trackent → Marqueur unique s'affiche
# Position se met à jour en temps réel
```

---

### 7️⃣ **BAR CHART - INTÉGRATION** (Priorité BASSE)
**What**: Vérifier fl_chart intégré et affiche stats

**Where**: 
- `/lib/widgets/group_stats_bar_chart.dart`
- `/lib/pages/group/admin_group_dashboard_page.dart`

**How**:
```bash
# Vérifier pubspec.yaml
fl_chart: ^0.70.0  # Ou version compatible

# Tester page dashboard
# Admin → Cliquer "Stats"
# Afficher bar chart distance/durée
```

**Test**:
```bash
# Sessions avec données
# Bar chart affiche distance km
# Bar chart affiche durée min
```

---

### 8️⃣ **EXPORTS CSV/JSON - TEST** (Priorité MOYENNE)
**What**: Tester exports sur web et mobile

**Where**: `/lib/services/group/group_export_service.dart`

**How**:
```bash
# Test mobile
# Historique → Export CSV → Vérifier fichier créé
# Historique → Export JSON → Vérifier partage

# Test web
# Historique → Export CSV → Vérifier download
# Historique → Export JSON → Vérifier download
```

**Format attendu**:
```csv
date,distance_m,duration_sec,ascent_m,descent_m,avg_speed_mps
2026-02-04,1250.5,3600,150.2,148.1,0.35
```

---

### 9️⃣ **TESTS E2E COMPLETS** (Priorité HAUTE)
**What**: Exécuter suite complète de tests

**How**:
```bash
# Test 1: Créer Admin
[ ] App → Tracking Groupe
[ ] Admin → Créer profil "Groupe Trail 2026"
[ ] Vérifier code 6 chiffres généré (ex: 123456)
[ ] Vérifier group_admin_codes/123456 dans Firestore

# Test 2: Rattacher Tracker
[ ] Autre compte → Tracking Groupe → Tracker
[ ] Saisir nom "Tracker 1" + code 123456
[ ] Cliquer "Se rattacher"
[ ] Vérifier group_trackers/{uid} créé avec adminGroupId=123456

# Test 3: Tracking GPS
[ ] Admin → Démarrer tracking
[ ] Attendre positions écrites dans Firestore
[ ] Vérifier group_tracks/123456/sessions/{id} créée

# Test 4: Position Moyenne
[ ] Tracker → Démarrer tracking
[ ] Admin + Tracker trackent 30s
[ ] Vérifier group_admins/{adminUid}.averagePosition calculée
[ ] Admin → Carte Live → Vérifier marqueur unique

# Test 5: Historique + Exports
[ ] Admin → Historique → Voir sessions
[ ] Cliquer session → Voir détails (durée, distance)
[ ] Export CSV → Vérifier format
[ ] Export JSON → Vérifier format

# Test 6: Permissions
[ ] Tracker A lié Admin 1
[ ] Tracker B lié Admin 2
[ ] Tracker A ne doit PAS voir données Tracker B
[ ] Admin1 masque visibilité → Tracker A ne voit plus average

# Test 7: Boutique
[ ] Admin → Boutique → Ajouter produit
[ ] Saisir titre, prix, stock, photo
[ ] Vérifier group_shops/123456/products/{id} créé
[ ] Tracker → Voir boutique admin
```

---

## 📋 CHECKLIST DÉPLOIEMENT

```
☐ Vérifier imports dans index.js (Cloud Function)
☐ firebase deploy --only functions
☐ firebase deploy --only firestore:rules
☐ firebase deploy --only storage
☐ Vérifier permissions Android/iOS
☐ Tester sur device/émulateur réel
☐ Vérifier Firestore Rules syntax
☐ Vérifier Cloud Function logs
☐ Tester intégration complète routes
☐ Exécuter suite tests E2E
☐ Vérifier bar chart affichage
☐ Vérifier exports CSV/JSON
```

---

## 🎯 RÉSUMÉ

| Composant | État | Priorité | ETA |
|-----------|------|----------|-----|
| Modèles Dart | ✅ OK | - | - |
| Services | ✅ OK | - | - |
| Pages UI | ✅ OK | - | - |
| Widgets | ✅ OK | - | - |
| Cloud Function | ✅ Code OK | 🔴 HAUTE | Aujourd'hui |
| Firestore Rules | ✅ Code OK | 🔴 HAUTE | Aujourd'hui |
| Routes Navigation | ⚠️ À intégrer | 🔴 HAUTE | Aujourd'hui |
| Storage Rules | ✅ À vérifier | 🟡 MOYENNE | Demain |
| Permissions GPS | ✅ À vérifier | 🔴 HAUTE | Aujourd'hui |
| Carte Live | ✅ À tester | 🟡 MOYENNE | Demain |
| Bar Chart | ✅ À tester | 🟢 BASSE | Semaine |
| Exports | ✅ À tester | 🟡 MOYENNE | Demain |
| Tests E2E | ⚠️ À faire | 🔴 HAUTE | Semaine |

---

**Generated**: 2026-02-04  
**By**: GitHub Copilot  
**Status**: Ready for finalization
