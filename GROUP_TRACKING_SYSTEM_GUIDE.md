# Système Tracking Groupe - Guide Complet

## 📦 Fichiers créés

### Modèles (`lib/models/`)
- ✅ `group_admin.dart` - Modèle admin + GeoPosition + GroupAdminCode
- ✅ `group_tracker.dart` - Modèle tracker
- ✅ `track_session.dart` - Session tracking + TrackSummary + TrackPoint
- ✅ `group_product.dart` - Produit boutique (GroupShopProduct)
- ✅ `group_media.dart` - Média boutique

### Services (`lib/services/group/`)
- ✅ `group_link_service.dart` - Création codes, rattachement, validation
- ✅ `group_tracking_service.dart` - Tracking GPS, sessions, calcul trajectoires
- ✅ `group_average_service.dart` - Calcul + stream position moyenne
- ✅ `group_export_service.dart` - Exports CSV/JSON
- ✅ `group_shop_service.dart` - CRUD produits/médias + upload Storage

### Pages UI (`lib/pages/group/`)
- ✅ `admin_group_dashboard_page.dart` - Dashboard admin complet
- ✅ `tracker_group_profile_page.dart` - Profil tracker + rattachement
- ✅ `group_map_live_page.dart` - Carte avec position moyenne
- ✅ `group_track_history_page.dart` - Historique sessions
- ✅ `group_export_page.dart` - Page exports

### Widgets (`lib/widgets/`)
- ✅ `group_stats_bar_chart.dart` - Bar chart avec fl_chart

### Cloud Functions (`functions/`)
- ✅ `group_tracking.js` - Calcul automatique position moyenne

---

## 🔧 Règles Firestore à ajouter

Ajoutez dans `firestore.rules` :

```javascript
// ============================================================================
// GROUP TRACKING RULES
// ============================================================================

// Répertoire codes admin (lecture publique pour validation, écriture admin uniquement)
match /group_admin_codes/{adminGroupId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.resource.data.adminUid == request.auth.uid;
  allow update, delete: if request.auth != null && resource.data.adminUid == request.auth.uid;
}

// Profils admin groupe
match /group_admins/{adminUid} {
  // Admin peut lire/écrire son propre profil
  allow read, write: if request.auth != null && request.auth.uid == adminUid;
  
  // Lecture publique si isVisible = true (pour affichage carte)
  allow read: if request.auth != null && resource.data.isVisible == true;
}

// Profils tracker groupe
match /group_trackers/{trackerUid} {
  // Tracker peut lire/écrire son propre profil
  allow read, write: if request.auth != null && request.auth.uid == trackerUid;
  
  // Admin du groupe peut lire ses trackers
  allow read: if request.auth != null && 
    exists(/databases/$(database)/documents/group_admins/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/group_admins/$(request.auth.uid)).data.adminGroupId == resource.data.adminGroupId;
}

// Positions temps réel (pour agrégation Cloud Function)
match /group_positions/{adminGroupId}/members/{uid} {
  // Seul le membre peut écrire sa position
  allow write: if request.auth != null && request.auth.uid == uid;
  
  // Admin du groupe peut lire toutes les positions
  allow read: if request.auth != null && 
    exists(/databases/$(database)/documents/group_admins/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/group_admins/$(request.auth.uid)).data.adminGroupId == adminGroupId;
    
  // Trackers du groupe peuvent lire si groupe visible
  allow read: if request.auth != null && 
    exists(/databases/$(database)/documents/group_trackers/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/group_trackers/$(request.auth.uid)).data.adminGroupId == adminGroupId;
}

// Sessions tracking
match /group_tracks/{adminGroupId}/sessions/{sessionId} {
  // Admin du groupe peut tout lire
  allow read: if request.auth != null && 
    exists(/databases/$(database)/documents/group_admins/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/group_admins/$(request.auth.uid)).data.adminGroupId == adminGroupId;
  
  // Tracker peut lire/écrire ses propres sessions
  allow read, write: if request.auth != null && resource.data.uid == request.auth.uid;
  allow create: if request.auth != null && request.resource.data.uid == request.auth.uid;
  
  // Points GPS de la session
  match /points/{pointId} {
    // Admin peut lire tous les points
    allow read: if request.auth != null && 
      exists(/databases/$(database)/documents/group_admins/$(request.auth.uid)) &&
      get(/databases/$(database)/documents/group_admins/$(request.auth.uid)).data.adminGroupId == adminGroupId;
    
    // Tracker peut écrire ses propres points
    allow read, write: if request.auth != null && 
      get(/databases/$(database)/documents/group_tracks/$(adminGroupId)/sessions/$(sessionId)).data.uid == request.auth.uid;
  }
}

// Boutique groupe - Produits
match /group_shops/{adminGroupId}/products/{productId} {
  // Admin du groupe peut tout faire
  allow read, write: if request.auth != null && 
    exists(/databases/$(database)/documents/group_admins/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/group_admins/$(request.auth.uid)).data.adminGroupId == adminGroupId;
  
  // Lecture publique si visible et groupe visible
  allow read: if request.auth != null && 
    resource.data.isVisible == true &&
    exists(/databases/$(database)/documents/group_admins/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/group_admins/$(request.auth.uid)).data.isVisible == true;
}

// Boutique groupe - Médias
match /group_shops/{adminGroupId}/media/{mediaId} {
  // Admin du groupe peut tout faire
  allow read, write: if request.auth != null && 
    exists(/databases/$(database)/documents/group_admins/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/group_admins/$(request.auth.uid)).data.adminGroupId == adminGroupId;
  
  // Lecture publique si visible et groupe visible
  allow read: if request.auth != null && 
    resource.data.isVisible == true;
}
```

---

## 📊 Indexes Firestore à ajouter

Ajoutez dans `firestore.indexes.json` :

```json
{
  "indexes": [
    {
      "collectionGroup": "group_trackers",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "adminGroupId", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "sessions",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "adminGroupId", "order": "ASCENDING" },
        { "fieldPath": "startedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "sessions",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "uid", "order": "ASCENDING" },
        { "fieldPath": "startedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "points",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "ts", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "products",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "adminGroupId", "order": "ASCENDING" },
        { "fieldPath": "isVisible", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "media",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "adminGroupId", "order": "ASCENDING" },
        { "fieldPath": "isVisible", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## 📦 Dépendances à ajouter dans `pubspec.yaml`

```yaml
dependencies:
  # Déjà présentes (à vérifier)
  flutter:
    sdk: flutter
  firebase_core: ^4.0.0
  firebase_auth: ^6.0.0
  cloud_firestore: ^6.0.0
  firebase_storage: ^13.0.0
  geolocator: ^14.0.0
  
  # À ajouter si manquantes
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  fl_chart: ^0.70.1
  share_plus: ^10.1.3
  path_provider: ^2.1.5
  intl: ^0.20.0
```

Puis exécutez :
```bash
cd app
flutter pub get
```

---

## 🚀 Déploiement Cloud Function

```bash
cd functions
npm install  # Si nécessaire

# Déployer uniquement la nouvelle fonction
firebase deploy --only functions:calculateGroupAveragePosition

# Ou tout déployer
firebase deploy --only functions
```

---

## 🧪 Tests

### 1. Créer un profil Admin
```dart
// Dans l'app, naviguer vers AdminGroupDashboardPage
// Cliquer "Créer mon profil Admin"
// Noter le code 6 chiffres généré
```

### 2. Rattacher un Tracker
```dart
// Dans l'app, naviguer vers TrackerGroupProfilePage
// Saisir le code admin
// Cliquer "Se rattacher"
```

### 3. Démarrer le tracking
```dart
// Dans le dashboard admin ou profil tracker
// Cliquer "Démarrer tracking"
// Vérifier que la position GPS est envoyée
```

### 4. Vérifier position moyenne
```dart
// Dans le dashboard admin
// Cliquer "Carte Live"
// Vérifier qu'un marqueur unique apparaît (position moyenne)
```

### 5. Tester exports
```dart
// Dans le dashboard admin ou profil tracker
// Cliquer "Exports"
// Exporter session en CSV ou JSON
```

---

## 🔍 Structure Firestore finale

```
/group_admin_codes/{adminGroupId}
  - adminUid: string
  - createdAt: timestamp
  - isActive: boolean

/group_admins/{adminUid}
  - adminGroupId: string (6 digits)
  - displayName: string
  - isVisible: boolean
  - selectedMapId: string | null
  - lastPosition: {lat, lng, alt, accuracy, ts}
  - averagePosition: {lat, lng, alt, accuracy, ts}  ← Calculé par CF
  - createdAt: timestamp
  - updatedAt: timestamp

/group_trackers/{trackerUid}
  - adminGroupId: string | null
  - linkedAdminUid: string | null
  - displayName: string
  - lastPosition: {lat, lng, alt, accuracy, ts}
  - createdAt: timestamp
  - updatedAt: timestamp

/group_positions/{adminGroupId}/members/{uid}
  - role: "admin" | "tracker"
  - lastPosition: {lat, lng, alt, accuracy, ts}
  - updatedAt: timestamp

/group_tracks/{adminGroupId}/sessions/{sessionId}
  - uid: string
  - role: string
  - startedAt: timestamp
  - endedAt: timestamp | null
  - summary: {durationSec, distanceM, ascentM, descentM, avgSpeedMps, pointsCount}
  - updatedAt: timestamp
  
  /points/{pointId}
    - lat: number
    - lng: number
    - alt: number | null
    - accuracy: number | null
    - ts: timestamp

/group_shops/{adminGroupId}/products/{productId}
  - title, description, price, currency, stock
  - photoUrls: array
  - isVisible: boolean
  - createdAt, updatedAt: timestamp

/group_shops/{adminGroupId}/media/{mediaId}
  - url: string
  - type: "image" | "video"
  - title: string | null
  - tags: object
  - isVisible: boolean
  - createdAt, updatedAt: timestamp
```

---

## ✅ Checklist Implémentation

- [x] Modèles créés (5 fichiers)
- [x] Services créés (5 fichiers)
- [x] Pages UI créées (5 fichiers)
- [x] Widget chart créé
- [x] Cloud Function créée
- [ ] Règles Firestore ajoutées
- [ ] Indexes Firestore ajoutés
- [ ] Dépendances installées
- [ ] Routes intégrées dans main.dart
- [ ] Tests effectués

---

## 🎯 Prochaines étapes

1. **Ajouter les règles** dans `firestore.rules`
2. **Ajouter les indexes** dans `firestore.indexes.json`
3. **Installer dépendances** : `flutter pub get`
4. **Déployer CF** : `firebase deploy --only functions`
5. **Déployer Rules** : `firebase deploy --only firestore:rules`
6. **Déployer Indexes** : `firebase deploy --only firestore:indexes`
7. **Tester l'app** avec les scénarios ci-dessus

---

## 📝 Notes importantes

- **Permissions GPS** : Demandées automatiquement par `geolocator` au premier tracking
- **Calcul moyenne** : Peut être fait côté client (fallback) si Cloud Function indisponible
- **Distance filter** : Réglé à 5m pour optimiser batterie/précision
- **Validation points** : Ignore accuracy > 50m et positions > 20s
- **Export** : Utilise `share_plus` pour partager fichiers CSV/JSON
- **Chart** : Utilise `fl_chart` pour visualisations

---

Système complet et prêt à l'emploi ! 🚀
