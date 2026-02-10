# ✅ CHECKLIST DÉPLOIEMENT FINAL - GROUP TRACKING SYSTEM

## Vérification préalable ✓

### Tâche 1: Routes dans main.dart
**Status**: ✅ COMPLÈTE
- Fichier: [app/lib/main.dart](app/lib/main.dart)
- Routes ajoutées:
  - `/group-admin` → AdminGroupDashboardPage ✓
  - `/group-tracker` → TrackerGroupProfilePage ✓
  - `/group-live` → GroupMapLivePage ✓
  - `/group-history` → GroupTrackHistoryPage ✓
  - `/group-export` → GroupExportPage ✓

### Tâche 4: Permissions GPS
**Status**: ✅ COMPLÈTE

#### Android
- Fichier: [app/android/app/src/main/AndroidManifest.xml](app/android/app/src/main/AndroidManifest.xml)
- ✅ `ACCESS_FINE_LOCATION` présent
- ✅ `ACCESS_COARSE_LOCATION` présent

#### iOS
- Fichier: [app/ios/Runner/Info.plist](app/ios/Runner/Info.plist)
- ✅ `NSLocationWhenInUseUsageDescription` présent
- Description: "Nous avons besoin de votre position pour vous recentrer sur la carte."

---

## Déploiement Firebase (À faire)

### Tâche 2: Cloud Function
**Status**: ⏳ À déployer

```bash
# Depuis le répertoire principal
firebase deploy --only functions:calculateGroupAveragePosition
```

**Fichiers concernés**:
- [functions/group_tracking.js](functions/group_tracking.js) - Cloud Function code
- [functions/index.js](functions/index.js) - Export (ligne 2008-2009)
- [firebase.json](firebase.json) - Configuration

**Qu'elle fait**:
- Trigger: `onDocumentWritten("group_positions/{adminGroupId}/members/{uid}")`
- Filtre positions valides (<20s, <50m précision)
- Calcule moyenne lat/lng/alt
- Met à jour `group_admins/{adminUid}.averagePosition`

### Tâche 3: Firestore Rules
**Status**: ⏳ À déployer

```bash
# Depuis le répertoire principal
firebase deploy --only firestore:rules
```

**Fichier**: [firestore.rules](firestore.rules)

**Règles principales**:
- `group_admin_codes`: Admin write, lookup read
- `group_admins`: Admin read/write own, tracker read averagePosition if isVisible
- `group_trackers`: Tracker read/write own, admin read linked trackers
- `group_positions`: Member write own, admin read all in group
- `group_tracks`: Member read/write own sessions, admin read all
- `group_shops`: Admin write, authenticated read if isVisible

### Tâche 3.5: Storage Rules (optionnel)
**Status**: ⏳ À déployer

```bash
# Depuis le répertoire principal
firebase deploy --only storage
```

**Fichier**: [storage.rules](storage.rules)

---

## Tests E2E (1-2 heures)

### Test 1: Admin création profil
```
Étapes:
1. Authentifier utilisateur comme admin
2. Cliquer /group-admin
3. Page affiche 6-digit code généré
4. Code sauvegardé en Firestore group_admin_codes
Résultat: ✓ Code affiché et unique
```

### Test 2: Tracker rattachement
```
Étapes:
1. Authentifier utilisateur comme tracker
2. Cliquer /group-tracker
3. Entrer code 6 chiffres
4. Cliquer "Se rattacher"
Résultat: ✓ Tracker lié à admin (Firestore group_trackers.linkedAdminUid)
```

### Test 3: GPS Tracking temps réel
```
Étapes:
1. Admin lance tracking: /group-admin → "Commencer"
2. Position écrite toutes les 5m
3. Vérifier Firestore group_positions/{adminGroupId}/members/{uid}
Résultat: ✓ Positions écrites en temps réel
```

### Test 4: Position moyenne visible
```
Étapes:
1. Ouvrir /group-live (carte)
2. Admin + 2+ trackers en suivi
3. Vérifier 1 marqueur unique = moyenne
4. Cloud Function calc averagePosition
Résultat: ✓ 1 marqueur, position mise à jour
```

### Test 5: Exports CSV/JSON
```
Étapes:
1. /group-export sélectionner session
2. Cliquer "Export CSV"
3. Vérifier fichier: distance (Haversine), duration, elevation
Résultat: ✓ Fichier téléchargé avec données correctes
```

### Test 6: Permissions GPS
```
Étapes:
1. Lancer app Android
2. First run: popup "Allow location"
3. Cliquer "Allow"
4. Vérifier Geolocator reçoit positions
Résultat: ✓ Permissions accordées
```

---

## Commandes rapides

```bash
# 1. Déployer Cloud Function
firebase deploy --only functions:calculateGroupAveragePosition

# 2. Déployer Firestore Rules
firebase deploy --only firestore:rules

# 3. Déployer Storage Rules
firebase deploy --only storage

# 4. Tout déployer (functions + rules + indexes)
firebase deploy --only functions,firestore:rules,firestore:indexes,storage

# 5. Vérifier statut
firebase deploy:list

# 6. Voir logs Cloud Function
firebase functions:log --lines 50
```

---

## Timeline

- **Aujourd'hui (2h)**: Déployer, vérifier permissions, test basique
- **Demain (2-3h)**: Tests E2E complets, corriger bugs
- **Cette semaine**: Tests en production, documentation utilisateur

---

## Notes

✅ = Complété
⏳ = À faire
⚠️ = À vérifier

Tous les fichiers source existent et sont prêts.
Aucune nouvelle code à écrire.
Seulement: Déployer + Tester.
