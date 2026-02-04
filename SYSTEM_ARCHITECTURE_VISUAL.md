# 🏗️ ARCHITECTURE SYSTÈME GROUP TRACKING

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                    MASLIVE - GROUP TRACKING                      │
└─────────────────────────────────────────────────────────────────┘

                          FLUTTER APP
                    ┌─────────────────────┐
                    │   UI Pages (5)      │
                    ├─────────────────────┤
                    │ • Admin Dashboard   │
                    │ • Tracker Profile   │
                    │ • Live Map          │
                    │ • History           │
                    │ • Export            │
                    └──────────┬──────────┘
                               │
                        ┌──────▼──────┐
                        │ Services(5) │
                        ├─────────────┤
                        │ • Link      │
                        │ • Tracking  │
                        │ • Average   │
                        │ • Export    │
                        │ • Shop      │
                        └──────┬──────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
           ┌────▼────┐  ┌─────▼─────┐  ┌────▼────┐
           │ Firebase│  │ Geolocator│  │ FL_CHART│
           │Firestore│  │   (GPS)   │  │(Graph)  │
           └────┬────┘  └───────────┘  └─────────┘
                │
    ┌───────────┼───────────┐
    │           │           │
┌───▼───┐  ┌────▼────┐  ┌──▼───┐
│Cloud  │  │Firestore│  │Storage│
│Functn │  │ Rules   │  │Rules  │
└───┬───┘  └────┬────┘  └──┬───┘
    │           │          │
    │  ┌────────▼──────────┤
    │  │ Firestore Database│
    │  │ (8 collections)   │
    │  └───────────────────┘
    │
    └──► group_positions/{id}/members/{uid}
         ↓ [trigger]
         calculateGroupAveragePosition()
         ↓
         Updates group_admins/{uid}.averagePosition
```

---

## Flux de données

### 1️⃣ Admin crée profil

```
Admin clicks "Nouveau groupe"
    ↓
AdminGroupDashboardPage.initState()
    ↓
GroupLinkService.createAdminProfile()
    ├→ generateUniqueAdminCode() [try up to 10 times]
    ├→ Save to group_admin_codes/123456
    ├→ Save to group_admins/{uid}
    └→ Display code on UI
```

### 2️⃣ Tracker se rattache

```
Tracker enters code "123456"
    ↓
TrackerGroupProfilePage._linkTracker()
    ↓
GroupLinkService.validateAdminCode("123456")
    ├→ Check group_admin_codes/123456 exists
    ├→ Check isActive = true
    └→ Return adminUid
    ↓
GroupLinkService.linkTrackerToAdmin()
    ├→ Create group_trackers/{trackerUid}
    │  └── adminGroupId, linkedAdminUid
    ├→ Create group_positions/{adminGroupId}/members/{trackerUid}
    └→ Show "Rattaché" on UI
```

### 3️⃣ GPS Tracking

```
Tracker clicks "Commencer"
    ↓
GroupTrackingService.startTracking()
    ├→ Create group_tracks/{adminGroupId}/sessions/{sessionId}
    ├→ Start Geolocator stream (distance filter: 5m)
    └→ Listen to position updates
    ↓
[Every 5m or time-based]
    ↓
_handleNewPosition()
    ├→ Write to group_tracks/{...}/sessions/{...}/points/{pointId}
    ├→ Write to group_positions/{adminGroupId}/members/{uid}.lastPosition
    ├→ Update group_admins or group_trackers.lastPosition
    └→ Cloud Function [AUTOMATIC TRIGGER]
        ↓
        calculateGroupAveragePosition()
        ├→ Read all group_positions/{adminGroupId}/members
        ├→ Filter valid: age < 20s, accuracy < 50m
        ├→ Calculate average: sum(lat)/count
        └→ Update group_admins/{adminUid}.averagePosition
```

### 4️⃣ Position moyenne visible

```
User opens /group-live
    ↓
GroupMapLivePage.build()
    ↓
StreamBuilder listening to GroupAverageService.streamAveragePosition()
    ├→ Firestore listener: group_admins/{uid}.averagePosition
    └→ Real-time updates
    ↓
Mapbox/FlutterMap renders
    ├→ 1 marker at average position
    └→ Updates every time averagePosition changes
```

### 5️⃣ Exports CSV/JSON

```
User selects session on /group-export
    ↓
GroupExportService.generateCSV(sessionId)
    ├→ Read session doc
    ├→ Read sub-collection points
    ├→ Calculate stats:
    │  ├─ distance: Haversine formula (lat1→lat2, lng1→lng2)
    │  ├─ duration: endTime - startTime
    │  ├─ ascent: sum(alt[i] - alt[i-1]) if > 0
    │  └─ descent: sum(alt[i] - alt[i-1]) if < 0
    └→ Format CSV rows
    ↓
GroupDownloadService.download() [platform-specific]
    ├─ Android/iOS: Share or Save
    ├─ Web: Trigger browser download
    └─ File: tracking_20250204_143000.csv
```

---

## Firestore Structure

```
firestore/
│
├── group_admin_codes/                    ← Lookup table
│   └── {adminGroupId} (doc)
│       ├── adminUid: "xyz123"
│       ├── isActive: true
│       ├── createdAt: timestamp
│       └── attempts: 1
│
├── group_admins/                         ← Admin profiles
│   └── {uid} (doc)
│       ├── adminGroupId: "123456"
│       ├── displayName: "Stéphane"
│       ├── isVisible: true/false         ← Toggle visibility
│       ├── selectedMapId: "mapbox"       ← Map dropdown
│       ├── lastPosition: {lat, lng, ts}
│       ├── averagePosition: {            ← Cloud Function updates this
│       │   lat, lng, alt, ts
│       │}
│       ├── createdAt: timestamp
│       └── updatedAt: timestamp
│
├── group_trackers/                       ← Tracker profiles
│   └── {uid} (doc)
│       ├── adminGroupId: "123456"
│       ├── linkedAdminUid: "xyz123"      ← Reference to admin
│       ├── displayName: "Jules"
│       ├── lastPosition: {lat, lng, ts}
│       └── createdAt: timestamp
│
├── group_positions/                      ← For Cloud Function
│   └── {adminGroupId}/members/ (sub)
│       └── {uid} (doc)
│           ├── lastPosition: {
│           │   lat, lng, alt,
│           │   accuracy, ts
│           │}
│           └── updatedAt: timestamp
│
├── group_tracks/                         ← Tracking sessions
│   └── {adminGroupId}/sessions/ (sub)
│       └── {sessionId} (doc)
│           ├── startedAt: timestamp
│           ├── endedAt: timestamp
│           ├── summary: {
│           │   distance_m: 523.45,
│           │   duration_sec: 900,
│           │   ascent_m: 12.5,
│           │   descent_m: 8.3,
│           │   avg_speed_mps: 0.58
│           │}
│           ├── adminGroupId: "123456"
│           └── points/ (sub-collection)
│               └── {pointId} (doc)
│                   ├── lat: 45.5001
│                   ├── lng: 2.5001
│                   ├── alt: 100.5
│                   ├── accuracy: 10
│                   └── ts: timestamp
│
├── group_shops/                          ← Boutique
│   └── {adminGroupId}/ (doc)
│       ├── products/ (sub-collection)
│       │   └── {productId} (doc)
│       │       ├── title: "Boisson"
│       │       ├── description: "..."
│       │       ├── price: 2.50
│       │       ├── stock: 100
│       │       ├── photos: ["gs://..."]
│       │       ├── isVisible: true
│       │       ├── createdAt: timestamp
│       │       └── updatedAt: timestamp
│       │
│       └── media/ (sub-collection)
│           └── {mediaId} (doc)
│               ├── url: "https://..."
│               ├── type: "image"
│               ├── tags: {hiking: true, fitness: false}
│               ├── isVisible: true
│               └── createdAt: timestamp
│
└── group_admin_codes_archive/             ← Optional: inactive codes
    └── {oldAdminGroupId} (doc)
        ├── adminUid: "xyz123"
        ├── isActive: false
        └── archivedAt: timestamp
```

---

## Services Architecture

### GroupLinkService

```dart
class GroupLinkService {
  Future<String> createAdminProfile(String displayName)
    → Génère code unique 6 chiffres
    → Crée documents group_admin_codes + group_admins
    → Retourne code généré
  
  Future<bool> validateAdminCode(String code)
    → Lookup dans group_admin_codes
    → Vérifie isActive = true
    → Retourne true si valide
  
  Future<void> linkTrackerToAdmin(String code, String displayName)
    → Valide code via validateAdminCode()
    → Crée document group_trackers/{uid}
    → Crée sous-collection group_positions/{adminGroupId}/members/{uid}
  
  Stream<GroupAdmin> streamAdminProfile(String uid)
    → Listener temps réel sur group_admins/{uid}
  
  Stream<List<GroupTracker>> streamAdminTrackers(String adminGroupId)
    → Listener temps réel sur group_trackers ?where adminGroupId
}
```

### GroupTrackingService

```dart
class GroupTrackingService {
  Future<void> startTracking(String adminGroupId, String role)
    → role = "admin" ou "tracker"
    → Crée TrackSession dans group_tracks/{adminGroupId}/sessions/{id}
    → Démarre Geolocator stream avec 5m distance filter
    → Écoute updates de position en continu
  
  Future<void> stopTracking()
    → Annule Geolocator stream
    → Calcule TrackSummary (distance, duration, elevation)
    → Update session document avec summary
  
  Future<void> _handleNewPosition(Position pos, String adminGroupId, String role)
    → Écrit point dans group_tracks/{...}/sessions/{...}/points/{id}
    → Écrit lastPosition dans group_admins ou group_trackers
    → Écrit pour Cloud Function: group_positions/{adminGroupId}/members/{uid}
    → Cloud Function se trigger automatiquement
}
```

### GroupAverageService

```dart
class GroupAverageService {
  Stream<GeoPosition> streamAveragePosition(String adminGroupId)
    → Listener Firestore: group_admins where adminGroupId
    → Retourne averagePosition en temps réel
    → Mis à jour par Cloud Function automatiquement
  
  Future<GeoPosition> calculateAveragePositionClient(String adminGroupId)
    → Fallback si Cloud Function échoue
    → Récupère tous members dans group_positions/{adminGroupId}/members
    → Filtre: age < 20s, accuracy < 50m
    → Calcule moyenne lat/lng/alt
}
```

### GroupExportService

```dart
class GroupExportService {
  Future<String> generateCSV(String sessionId, String adminGroupId)
    → Récupère session + points de Firestore
    → Calcule distance (Haversine), duration, elevation
    → Formate CSV: date,distance_m,duration_sec,ascent_m,descent_m,avg_speed_mps
  
  Future<Map<String, dynamic>> generateJSON(...)
    → Même données en JSON format
}
```

### GroupShopService

```dart
class GroupShopService {
  Future<void> addProduct(String adminGroupId, GroupProduct product)
    → Crée document dans group_shops/{adminGroupId}/products/{id}
  
  Future<void> addMedia(String adminGroupId, GroupMedia media)
    → Crée document dans group_shops/{adminGroupId}/media/{id}
  
  Future<String> uploadPhotoToStorage(String adminGroupId, File file)
    → Uploads file vers gs://bucket/group_shops/{adminGroupId}/photos/{id}
    → Retourne download URL
  
  Future<void> updateStock(String adminGroupId, String productId, int stock)
    → Update field stock dans group_shops/{adminGroupId}/products/{productId}
}
```

---

## Cloud Function: calculateGroupAveragePosition

```javascript
/**
 * Trigger: onDocumentWritten("group_positions/{adminGroupId}/members/{uid}")
 * 
 * Exécution:
 * 1. Un tracker écrit sa position → group_positions/123456/members/uid
 * 2. Cloud Function se déclenche automatiquement
 * 3. Récupère tous les members du groupe
 * 4. Filtre positions valides:
 *    - age < 20 secondes
 *    - accuracy < 50 mètres
 * 5. Calcule moyenne: sum(lat)/count, sum(lng)/count, sum(alt)/count
 * 6. Update: group_admins/{adminUid}.averagePosition
 * 7. Client-side UI se met à jour via StreamBuilder
 */

exports.calculateGroupAveragePosition = onDocumentWritten(
  "group_positions/{adminGroupId}/members/{uid}",
  async (event) => {
    const adminGroupId = event.params.adminGroupId;
    
    // Récupère tous les positions du groupe
    const membersSnapshot = await db
      .collection("group_positions")
      .doc(adminGroupId)
      .collection("members")
      .get();
    
    // Filtre positions valides
    const validPositions = [];
    const now = Date.now();
    const MAX_AGE_MS = 20 * 1000;     // 20 secondes
    const MAX_ACCURACY = 50;           // 50 mètres
    
    membersSnapshot.forEach((doc) => {
      const data = doc.data();
      if (!data.lastPosition) return;
      
      const pos = data.lastPosition;
      const timestamp = pos.ts?.toMillis() || 0;
      const age = now - timestamp;
      
      // Ignore si trop ancien ou trop imprécis
      if (age > MAX_AGE_MS) return;
      if (pos.accuracy && pos.accuracy > MAX_ACCURACY) return;
      
      validPositions.push({
        lat: pos.lat,
        lng: pos.lng,
        alt: pos.alt
      });
    });
    
    // Calcule moyenne
    const avgLat = validPositions.reduce((s, p) => s + p.lat, 0) / validPositions.length;
    const avgLng = validPositions.reduce((s, p) => s + p.lng, 0) / validPositions.length;
    const avgAlt = ...;
    
    // Update admin profile
    const adminSnapshot = await db
      .collection("group_admins")
      .where("adminGroupId", "==", adminGroupId)
      .limit(1)
      .get();
    
    const adminDoc = adminSnapshot.docs[0];
    await adminDoc.ref.update({
      averagePosition: {
        lat: avgLat,
        lng: avgLng,
        alt: avgAlt,
        ts: new Date()
      }
    });
  }
);
```

---

## Firestore Rules (Résumé)

```
match /group_admin_codes/{adminGroupId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && 
                  request.resource.data.adminUid == request.auth.uid;
}

match /group_admins/{uid} {
  allow read, write: if uid == request.auth.uid;
  allow read: if resource.data.isVisible == true && 
                 request.auth != null;
}

match /group_trackers/{uid} {
  allow read, write: if uid == request.auth.uid;
  allow read: if resource.data.linkedAdminUid == request.auth.uid;
}

match /group_positions/{adminGroupId}/members/{uid} {
  allow write: if uid == request.auth.uid;
  allow read: if get(/databases/$(database)/documents/group_admins/
                     $(request.auth.uid))
              .data.adminGroupId == adminGroupId;
}

match /group_tracks/{adminGroupId}/sessions/{sessionId} {
  allow read: if sessionId owner == request.auth.uid ||
                 admin has role;
  match /points/{pointId} {
    allow read, write: if sessionId owner == request.auth.uid;
  }
}
```

---

## Pages UI (5)

```
/group-admin (AdminGroupDashboardPage)
├─ Display 6-digit code
├─ Toggle isVisible (Visibilité Groupe)
├─ Map dropdown (selectedMapId)
├─ List of linked trackers
│  └─ Show: name, position, "Online/Offline"
├─ Button: "Start Tracking" / "Stop Tracking"
├─ Button: "View History"
├─ Button: "Exports"
├─ Button: "Shop"
└─ Button: "Statistics"

/group-tracker (TrackerGroupProfilePage)
├─ Input: 6-digit code
├─ Input: Display name
├─ Button: "Link to Admin"
├─ Status: "Linked to Admin X" or "Not linked"
├─ Button: "Start Tracking" / "Stop Tracking"
├─ Button: "View History"
└─ Button: "Exports"

/group-live (GroupMapLivePage)
├─ Mapbox/FlutterMap display
├─ 1 Marker = averagePosition
├─ Update in real-time
├─ Zoom/pan controls
└─ Map selection: Mapbox, Default, etc

/group-history (GroupTrackHistoryPage)
├─ List sessions (cards)
├─ Sort by date descending
├─ Each card: date, duration, distance
├─ Tap to view details
├─ Actions: edit, delete
└─ Export button per session

/group-export (GroupExportPage)
├─ Select session from dropdown
├─ Button: "Export CSV"
├─ Button: "Export JSON"
├─ Share/Download options
├─ Preview data (optional)
└─ Cross-platform support
```

---

## Widgets (1)

```
GroupStatsBarChart
├─ Uses FL_CHART BarChart
├─ X-axis: Sessions (date)
├─ Y-axis Left: Distance (km)
├─ Y-axis Right: Duration (minutes)
├─ Bars color-coded
├─ Responsive to device size
└─ Tap to see values
```

---

## Summary

```
Total Files: 17
├─ Models: 6
├─ Services: 5
├─ Pages: 5
├─ Widgets: 1
└─ Cloud Function: 1

Total Lines of Code: ~3,500+
Firestore Collections: 8
Security Rules: 15+ rules
Cloud Function Triggers: 1

Status: ✅ COMPLETE - Ready to deploy
Deployment: 3 Firebase commands
Tests: 8 E2E tests provided
Time to Production: 1-2 hours
```
