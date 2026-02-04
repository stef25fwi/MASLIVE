# 🧪 Guide de test - Group Map Visibility Feature

**Date**: 04/02/2026  
**Feature**: Visibilité groupe sur cartes  
**Environment**: Web (masslive.web.app)  

---

## ✅ Checklist pre-test

Avant de commencer les tests:

- [ ] App déployée: `https://masslive.web.app`
- [ ] Console browser ouverte: F12 → Console
- [ ] Firestore connectée et accessible
- [ ] Au moins 1 compte admin créé
- [ ] Au moins 1 groupe créé
- [ ] Au moins 1 mapper preset configuré

---

## 🧪 Test 1: Widget apparaît sur dashboard

### Étapes

```
1. Accéder: https://masslive.web.app/#/group/admin
2. Scroller vers le bas du dashboard
3. Chercher section "Visibilité sur les cartes"
```

### Vérifications

- [ ] ✅ Section visible
- [ ] ✅ Titre "Visibilité sur les cartes" affiché
- [ ] ✅ Icône ℹ️ (info) visible
- [ ] ✅ Liste de cartes affichée

### Expected output

```
┌──────────────────────────────────────┐
│ 🗺️  Visibilité sur les cartes       ℹ️ │
├──────────────────────────────────────┤
│ ☐ Carte Générale                     │
│ ☐ Carte Événements                   │
│ ☐ Carte Trail 2026                   │
│ ☐ Carte Test                         │
└──────────────────────────────────────┘
```

### Console logs

```bash
// Attendu:
// GroupMapVisibilityWidget initialized
// Streaming presets...
// Streaming visible maps...
// Presets loaded: [Carte Générale, Carte Événements, ...]
```

---

## 🧪 Test 2: Toggle une carte - Checkbox update

### Étapes

```
1. Sur dashboard admin groupe
2. Cocher la checkbox "Carte Générale"
3. Vérifier la checkbox est maintenant cochée
4. Décocher la checkbox
5. Vérifier la checkbox est maintenant décochée
```

### Vérifications

- [ ] ✅ Checkbox state change immédiat (<100ms)
- [ ] ✅ Icône 👁️ (visible) ou 👁️‍🗨️ (hidden) updated
- [ ] ✅ Pas d'erreur console

### Expected output

```
// Avant:
☐ Carte Générale                    👁️‍🗨️
// Après click (cochée):
☑ Carte Générale                    👁️
// Après click (décochée):
☐ Carte Générale                    👁️‍🗨️
```

### Console logs

```bash
// Attendu:
// Map visibility toggled: map_1 → true
// Firestore update: visibleMapIds added 'map_1'
// [SUCCESS] Update completed
```

---

## 🧪 Test 3: Firestore synchronisation

### Étapes

```
1. Sur dashboard, cocher "Carte Générale" et "Carte Événements"
2. Ouvrir console.firebase.google.com
3. Naviguer: Firestore → group_admins → {adminUid}
4. Vérifier le champ visibleMapIds
```

### Vérifications

- [ ] ✅ Champ `visibleMapIds` existe
- [ ] ✅ Contient ["map_1", "map_3"] (ou les ids correctes)
- [ ] ✅ Timestamp `updatedAt` récent

### Expected Firestore document

```json
{
  "adminGroupId": "ABC123",
  "displayName": "Groupe Trail",
  "visibleMapIds": ["map_1", "map_3"],
  "lastPosition": {...},
  "averagePosition": {...},
  "updatedAt": Timestamp(2026-02-04T...),
  ...
}
```

### Firestore query

```javascript
// Console Firestore:
db.collection("group_admins")
  .where("visibleMapIds", "array-contains", "map_1")
  .get()
  .then(docs => {
    console.log(docs.size, "groups visible on map_1");
  });

// Expected: 1 group(s) visible on map_1
```

---

## 🧪 Test 4: Real-time stream updates

### Étapes

```
1. Ouvrir app en 2 onglets différents
2. Onglet 1: Dashboard admin groupe
3. Onglet 2: Ouvrir DevTools → Application → Local Storage
4. Onglet 1: Cocher une carte
5. Onglet 2: Vérifier cache local updated
```

### Vérifications

- [ ] ✅ Change visible dans onglet 1 (<100ms)
- [ ] ✅ Firestore synchronized (<2s)
- [ ] ✅ Local cache updated (Hive)

### Console logs (Browser DevTools)

```bash
// Onglet 1 - Dashboard:
// GroupMapVisibilityWidget.onChanged: toggled map_1

// Onglet 1 - Service:
// GroupMapVisibilityService.toggleMapVisibility(map_1, true)
// Firestore FieldValue.arrayUnion('map_1')

// Onglet 1 - Stream:
// StreamController emitted new visibleMapIds: ['map_1', 'map_3']

// Onglet 1 - UI:
// CheckboxListTile state updated → rebuild
```

---

## 🧪 Test 5: Multiple maps toggle

### Étapes

```
1. Cocher "Carte Générale"
2. Vérifier ✅ + icône 👁️
3. Cocher "Carte Événements"
4. Vérifier ✅ + icône 👁️ + 1ère toujours ✅
5. Cocher "Carte Trail"
6. Décocher "Carte Générale"
7. Vérifier visibleMapIds = ["map_2", "map_3", "map_4"]
```

### Vérifications

- [ ] ✅ Peuvent cocher/décocher indépendamment
- [ ] ✅ État correct après chaque action
- [ ] ✅ Firestore maintient liste exacte

### Expected sequence

```
Firestore visibleMapIds:
1. [] (initial)
2. ["map_1"] (after check Générale)
3. ["map_1", "map_2"] (after check Événements)
4. ["map_1", "map_2", "map_3"] (after check Trail)
5. ["map_2", "map_3"] (after uncheck Générale)
```

---

## 🧪 Test 6: Map visibility on map page

### Étapes

```
1. Go to Map page (home)
2. Select "Carte Générale" from dropdown
3. Verify group marker appears on map
4. Go back to Dashboard → uncheck "Carte Générale"
5. Go to Map page again → verify group marker disappeared
```

### Vérifications

- [ ] ✅ Groupe visible si dans visibleMapIds
- [ ] ✅ Groupe caché si pas dans visibleMapIds
- [ ] ✅ Position moyenne (centroïd) affichée
- [ ] ✅ Marker clickable → affiche détails

### Map markers

```
Avant:
  • Carte Générale: Groupe "Trail" + 3 trackers
  
Après uncheck "Carte Générale":
  • Carte Générale: ∅ (groupe caché)
```

---

## 🧪 Test 7: Error handling

### Étapes

### 7.1 Pas de connexion Firestore

```
1. Ouvrir DevTools → Network → Offline
2. Essayer cocher une carte
3. Attendre 30 sec
4. Mettre Online
```

**Expected**: 
- [ ] ✅ Retry automatique après reconnect
- [ ] ✅ Cache local utilisé (optimistic update)
- [ ] ✅ Pas de crash app

### 7.2 Quota Firestore dépassé

```
// Logs Firestore:
// PERMISSION_DENIED: User does not have permission...
```

**Expected**:
- [ ] ✅ Erreur affichée à l'user (toast/snackbar)
- [ ] ✅ Pas de crash app
- [ ] ✅ Toggle reverts

### 7.3 Stream timeout

```
// Si stream prend >30s (timeout)
```

**Expected**:
- [ ] ✅ Erreur catchée
- [ ] ✅ Fallback à cache local
- [ ] ✅ Message warning user

### Test commands

```bash
# Simuler erreur Firestore
curl -X POST http://localhost:8080/emulator/v1/projects/{project}/instances

# Voir logs d'erreur
firebase functions:log --tail | grep ERROR
```

---

## 🧪 Test 8: Performance

### Étapes

### 8.1 Bench toggle speed

```
1. Dashboard ouvert
2. F12 → Console → Perf timer
3. Cocher/décocher 5 fois
4. Mesurer temps moyen
```

**Expected**: 
```
Toggle response: < 500ms (local update)
Firestore sync: < 2s (server confirmation)
```

### 8.2 Multiple groups

```
1. Créer 10 groupes
2. Chaque groupe: 5 cartes visibles
3. Évaluer performance dashboard
```

**Expected**:
- [ ] ✅ Page charge < 2s
- [ ] ✅ Pas de lag scroll
- [ ] ✅ Stream handles bien

### Commands

```bash
# Mesurer bundle size
du -sh /workspaces/MASLIVE/app/build/web/

# Performance metrics
firebase apps:list --json | jq '.[] | {name, bundleSize}'
```

---

## 🧪 Test 9: Permissions & Security

### Étapes

### 9.1 Admin peut edit sa visibilité

```
1. Login as Admin A
2. Toggle visibilité son groupe
3. Vérifier Firestore updated
```

**Expected**: ✅ Update successful

### 9.2 Admin B ne peut pas edit Admin A

```
1. Login as Admin A → noter groupId (ABC123)
2. Logout
3. Login as Admin B
4. Essayer POST: /group_admins/adminA_uid/visibleMapIds
5. Vérifier erreur Firestore
```

**Expected**: 
```
Error: PERMISSION_DENIED
User does not have permission to update this document
```

### 9.3 Tracker peut lire visibilité

```
1. Login as Tracker X
2. Linked to Admin A group
3. Vérifier peut lire visibleMapIds
4. Vérifier peut voir groupe sur cartes visibles
```

**Expected**: ✅ Lecture OK, écriture denied

---

## 🧪 Test 10: Edge cases

### 10.1 Zero visible maps

```
1. Décocher toutes les cartes
2. visibleMapIds = [] (array vide)
3. Groupe n'apparaît sur aucune carte
```

**Expected**: ✅ Works correctly

### 10.2 Max visible maps

```
1. Cocher 10+ cartes
2. Firestore limit: no limit (arrays can be large)
3. Performance: still <500ms
```

**Expected**: ✅ No limit enforced

### 10.3 Duplicate maps

```
1. Firestore: visibleMapIds = ["map_1", "map_1"]
2. Widget should deduplicate
```

**Expected**: 
- [ ] ✅ Displayed only once
- [ ] ✅ Checkboxes handle duplicates

### 10.4 Invalid map IDs

```
1. Firestore: visibleMapIds = ["map_1", "invalid_id"]
2. Widget loads presets
3. "invalid_id" not in presets list
```

**Expected**:
- [ ] ✅ Error logged
- [ ] ✅ Valid maps displayed normally
- [ ] ✅ Invalid ID silently ignored or shown greyed out

---

## 📊 Test Results Summary

| Test # | Name | Status | Duration | Notes |
|--------|------|--------|----------|-------|
| 1 | Widget appears | ☐ | | |
| 2 | Checkbox toggle | ☐ | | |
| 3 | Firestore sync | ☐ | | |
| 4 | Real-time stream | ☐ | | |
| 5 | Multiple maps | ☐ | | |
| 6 | Map visibility | ☐ | | |
| 7 | Error handling | ☐ | | |
| 8 | Performance | ☐ | | |
| 9 | Permissions | ☐ | | |
| 10 | Edge cases | ☐ | | |

**Overall Status**: ☐ PASS / ☐ FAIL

---

## 🐛 Bug reporting

Si vous trouvez un bug durant les tests:

```markdown
## Bug: [Short title]

**Steps to reproduce**:
1. ...
2. ...
3. ...

**Expected**: 
- What should happen

**Actual**:
- What actually happens

**Console logs**:
```
[paste error logs]
```

**Device**: Chrome/Firefox/Safari
**OS**: Windows/Mac/Linux
**App version**: v1.0.0
**Timestamp**: 2026-02-04 14:30:00 UTC
```

---

## ✅ Sign-off

```
Tested by: _____________________
Date: _____________________
Status: ☐ PASS ☐ FAIL

All tests passed and feature is ready for production deployment.
```

---

## 🔗 Références rapides

- Feature doc: [FEATURE_GROUP_MAP_VISIBILITY.md](FEATURE_GROUP_MAP_VISIBILITY.md)
- Config doc: [CONFIG_GROUP_MAP_VISIBILITY.md](CONFIG_GROUP_MAP_VISIBILITY.md)
- Deployment: [DEPLOYMENT_CHECKLIST_MAP_VISIBILITY.md](DEPLOYMENT_CHECKLIST_MAP_VISIBILITY.md)
- Dashboard code: [admin_group_dashboard_page.dart](app/lib/pages/group/admin_group_dashboard_page.dart)
- Service code: [group_map_visibility_service.dart](app/lib/services/group/group_map_visibility_service.dart)
- Widget code: [group_map_visibility_widget.dart](app/lib/widgets/group_map_visibility_widget.dart)

---

**Testing Framework**: Dart test + Firebase Emulator + Browser DevTools  
**Test Env**: https://masslive.web.app (production)  
**Last Updated**: 04/02/2026

