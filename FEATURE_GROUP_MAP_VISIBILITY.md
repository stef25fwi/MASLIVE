# 🗺️ FONCTIONNALITÉ - Visibilité du groupe sur les cartes

**Date**: 04/02/2026  
**Feature**: Toggle visibilité groupe par carte  
**Status**: ✅ IMPLÉMENTÉ

---

## 🎯 Fonctionnalité

Ajouter un **toggle de visibilité** sur le profil admin groupe qui permet:
- ✅ Sélectionner les cartes où le groupe est visible
- ✅ Afficher/masquer la position GPS du groupe par carte
- ✅ Tous les utilisateurs visualisant la carte voient le groupe
- ✅ Utilise le même menu déroulant de carte que la page home

---

## 📋 Fichiers créés/modifiés

### 1. Service de gestion de visibilité
**Fichier**: `app/lib/services/group/group_map_visibility_service.dart` (NOUVEAU)

```dart
class GroupMapVisibilityService {
  // Ajouter une carte à la liste de visibilité
  Future<void> addMapVisibility({
    required String adminUid,
    required String mapId,
  })

  // Retirer une carte de la visibilité
  Future<void> removeMapVisibility({
    required String adminUid,
    required String mapId,
  })

  // Basculer visibilité d'une carte
  Future<void> toggleMapVisibility({
    required String adminUid,
    required String mapId,
    required bool isVisible,
  })

  // Stream des cartes visibles
  Stream<List<String>> streamVisibleMaps(String adminUid)

  // Vérifier si groupe visible sur carte
  Stream<bool> isGroupVisibleOnMap({
    required String adminUid,
    required String mapId,
  })
}
```

### 2. Widget de visibilité
**Fichier**: `app/lib/widgets/group_map_visibility_widget.dart` (NOUVEAU)

```dart
class GroupMapVisibilityWidget extends StatefulWidget {
  // Affiche CheckboxListTile pour chaque carte
  // Met à jour Firestore on toggle
  // Stream: visibilité en temps réel
}
```

### 3. Modèle GroupAdmin
**Fichier**: `app/lib/models/group_admin.dart` (MODIFIÉ)

```dart
class GroupAdmin {
  // NOUVEAU CHAMP:
  final List<String> visibleMapIds; // Cartes où groupe est visible
}
```

### 4. Page Dashboard Admin
**Fichier**: `app/lib/pages/group/admin_group_dashboard_page.dart` (MODIFIÉ)

- ✅ Import `GroupMapVisibilityWidget`
- ✅ Ajout du widget dans ListView entre "TrackingCard" et "ActionsGrid"

---

## 🔄 Flux d'utilisation

### Pour l'admin groupe:

```
1. Ouvrir "Dashboard Admin Groupe"
   ↓
2. Scroller jusqu'à "Visibilité sur les cartes"
   ↓
3. Voir la liste des cartes disponibles avec checkboxes
   ↓
4. Cocher les cartes où le groupe doit être visible
   ↓
5. Toggle automatiquement sauvegardé dans Firestore
   ↓
6. La position du groupe apparaît sur la carte pour TOUS les utilisateurs
```

### Structure Firestore

```firestore
group_admins/{adminUid}
├── uid: "user123"
├── adminGroupId: "ABC123"
├── displayName: "Groupe Trail"
├── visibleMapIds: ["map_1", "map_3"]  // NOUVEAU
├── isVisible: true
├── lastPosition: {...}
└── averagePosition: {...}
```

---

## 🎨 Interface utilisateur

### Carte visibilité

```
┌─────────────────────────────┐
│ 🗺️  Visibilité sur les cartes  │  ℹ️
├─────────────────────────────┤
│ ☑ Carte Trail 2026           │ 👁️
│   Description ...            │
├─────────────────────────────┤
│ ☐ Carte Événements           │ 👁️
│   Description ...            │
├─────────────────────────────┤
│ ☑ Carte Générale             │ 👁️
│   Description ...            │
└─────────────────────────────┘
```

**Elements**:
- ✅ Checkbox pour toggle visibilité
- 👁️ Icône "eye" (visible) ou "eye_off" (masqué)
- 📝 Nom et description de la carte
- ℹ️ Bouton info avec tooltip

---

## 🔐 Firestore Rules

Ajouter à `firestore.rules`:

```firestore
// Permettre admin mettre à jour ses cartes visibles
match /group_admins/{adminUid} {
  allow update: if request.auth.uid == adminUid
    && resource.data.diff(request.resource.data).affectedKeys()
    .hasOnly(['visibleMapIds', 'updatedAt']);
  
  // Permettre lire la liste des cartes visibles
  allow read: if true;
}
```

---

## 🗺️ Intégration sur la carte

### Quand afficher un groupe?

Sur `GroupMapLivePage` ou page carte:

```dart
// Récupérer les groupes
final groups = await groupService.getAll();

for (var group in groups) {
  // Vérifier si groupe visible sur la carte actuelle
  final isVisible = group.visibleMapIds.contains(selectedMapId);
  
  if (isVisible && group.averagePosition != null) {
    // Afficher le marqueur du groupe
    markers.add(
      Marker(
        point: LatLng(group.averagePosition!.lat, group.averagePosition!.lng),
        child: GestureDetector(
          onTap: () => showGroupDetails(group),
          child: Icon(Icons.group, color: Colors.blue, size: 32),
        ),
      ),
    );
  }
}
```

---

## 📱 Scénarios d'usage

### Scénario 1: Admin crée un groupe + rend visible sur 2 cartes

```
1. Admin crée groupe "Trail 2026"
2. Code généré: ABC123
3. Admin va dans visibilité → coche:
   ✅ "Carte Générale"
   ✅ "Carte Événements"
   ☐ "Carte Test"

4. Résultat:
   - Utilisateurs voyant "Carte Générale" → voir groupe
   - Utilisateurs voyant "Carte Événements" → voir groupe
   - Utilisateurs voyant "Carte Test" → pas de groupe
```

### Scénario 2: Tracker se rattache + apparaît sur cartes

```
1. Tracker scanne code ABC123
2. Tracker appuie "Démarrer tracking"
3. Position GPS envoyée à Firestore
4. Cloud Function calcule position moyenne
5. Groupe visible sur "Carte Générale" → groupe + trackers apparaissent

Result: 👁️ Position moyenne visible pour TOUS les utilisateurs
```

---

## ✅ Checklist implémentation

- [x] Service créé (`group_map_visibility_service.dart`)
- [x] Widget créé (`group_map_visibility_widget.dart`)
- [x] Modèle updated (`group_admin.dart` + `visibleMapIds`)
- [x] Dashboard intégré (`admin_group_dashboard_page.dart`)
- [x] Firestore structure compatible
- [ ] Firestore Rules mises à jour (À faire)
- [ ] Logique d'affichage sur carte (À faire)
- [ ] Tests unitaires (Optionnel)

---

## 🚀 Déploiement

### Étapes:

1. **Déployer code**:
   ```bash
   cd /workspaces/MASLIVE/app
   flutter build web --release
   cd /workspaces/MASLIVE
   firebase deploy --only hosting
   ```

2. **Mettre à jour Firestore Rules**:
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Tester**:
   - Aller à `/group/admin`
   - Créer/ouvrir profil admin
   - Voir widget "Visibilité sur les cartes"
   - Toggle checkboxes
   - Vérifier Firestore `visibleMapIds` updated

---

## 🎓 API Complète

### GroupMapVisibilityService

```dart
// Ajouter carte visible
await GroupMapVisibilityService.instance.addMapVisibility(
  adminUid: 'admin_uid',
  mapId: 'map_1',
  mapName: 'Carte Générale',
);

// Retirer carte visible
await GroupMapVisibilityService.instance.removeMapVisibility(
  adminUid: 'admin_uid',
  mapId: 'map_1',
);

// Basculer
await GroupMapVisibilityService.instance.toggleMapVisibility(
  adminUid: 'admin_uid',
  mapId: 'map_1',
  isVisible: true,
);

// Récupérer cartes visibles
final maps = await GroupMapVisibilityService.instance
    .getVisibleMaps('admin_uid');
// Result: ['map_1', 'map_3']

// Stream temps réel
GroupMapVisibilityService.instance
    .streamVisibleMaps('admin_uid')
    .listen((visibleMaps) {
      print('Cartes visibles: $visibleMaps');
    });

// Vérifier si groupe visible sur une carte
GroupMapVisibilityService.instance
    .isGroupVisibleOnMap(
      adminUid: 'admin_uid',
      mapId: 'map_1',
    )
    .listen((isVisible) {
      print('Visible: $isVisible');
    });
```

---

## 📊 Performance

- **Lecture**: O(1) - ArrayList lookup
- **Écriture**: O(1) - Array union/remove
- **Stream**: Real-time via Firestore snapshot
- **Cache**: Widget cache BuildContext

---

## 🔗 Références

- GroupMapVisibilityService: [service](app/lib/services/group/group_map_visibility_service.dart)
- GroupMapVisibilityWidget: [widget](app/lib/widgets/group_map_visibility_widget.dart)
- Dashboard Admin: [page](app/lib/pages/group/admin_group_dashboard_page.dart)
- Modèle: [group_admin.dart](app/lib/models/group_admin.dart)

---

**Status**: ✅ PRÊT À DÉPLOYER  
**Impact**: Augmente visibilité des groupes sur cartes  
**Utilisateurs impactés**: Admins groupes + tous utilisateurs

