# 🧪 TESTS E2E - GROUP TRACKING SYSTEM

## Guide complet des tests d'intégration

### Setup de test

```
Prérequis:
- App compilée en web mode (flutter build web)
- Firebase déployée (Cloud Functions + Rules)
- 2+ comptes Firebase créés:
  - Compte A: Admin
  - Compte B: Tracker 1
  - Compte C: Tracker 2 (optionnel)
- Device avec GPS (physique ou émulateur)
```

---

## Test 1: Admin crée un profil et reçoit un code unique

**Durée**: 5 minutes
**Dépendances**: Aucune

### Étapes

1. **Authentification**
   ```
   - Login avec Compte A (admin)
   - Vérifier authentification réussie
   ```

2. **Navigation vers dashboard admin**
   ```
   - Cliquer menu → "Groupe" ou aller à /group-admin
   - Page AdminGroupDashboardPage doit charger
   ```

3. **Vérifier génération code**
   ```
   - Observer un code 6 chiffres affiché (ex: 123456)
   - Code doit être unique à chaque reload
   - Code doit être lisible (police grande, couleur contrastée)
   ```

4. **Vérifier persistence Firestore**
   ```
   - Ouvrir Firebase Console
   - Collections → group_admin_codes
   - Vérifier document avec:
     * adminGroupId: "123456" (le code affiché)
     * adminUid: UID du compte A
     * isActive: true
     * createdAt: timestamp valide
   
   - Collections → group_admins
   - Vérifier document avec:
     * uid: UID du compte A
     * adminGroupId: "123456"
     * displayName: "Compte A" ou vide
     * isVisible: false (initial)
     * lastPosition: null (initial)
     * averagePosition: null (initial)
   ```

5. **Vérifier dupliquats**
   ```
   - Recharger la page
   - Observer le même code 6 chiffres (pas nouveau)
   - Vérifier qu'un seul document existe dans group_admin_codes
   ```

### Résultat attendu

- ✅ Code 6 chiffres affiché à l'écran
- ✅ Document group_admin_codes créé
- ✅ Document group_admins créé
- ✅ Code identique au reload
- ✅ Pas de doublons

### Troubleshooting

| Problème | Solution |
|----------|----------|
| Code non affiché | Vérifier GroupLinkService.createAdminProfile() |
| Code change à chaque reload | Vérifier findExistingCode() |
| Pas de document Firestore | Vérifier permissions Firestore Rules |
| Erreur 403 Permission denied | Vérifier rule: create if auth != null |

---

## Test 2: Tracker se rattache à un admin avec le code

**Durée**: 5 minutes
**Dépendances**: Test 1 réussi

### Étapes

1. **Authentification tracker**
   ```
   - Logout du compte A
   - Login avec Compte B (tracker)
   - Vérifier authentification réussie
   ```

2. **Navigation vers profil tracker**
   ```
   - Cliquer menu → "Tracker Groupe" ou aller à /group-tracker
   - Page TrackerGroupProfilePage doit charger
   - Statut initial: "Non rattaché"
   ```

3. **Entrer le code admin**
   ```
   - Dans TextField "Code Admin (6 chiffres)"
   - Entrer le code du Test 1 (ex: 123456)
   - TextField doit accepter que 6 caractères numériques
   ```

4. **Valider rattachement**
   ```
   - Cliquer bouton "Se rattacher"
   - Page doit afficher: "Rattaché à [admin displayName]"
   - Doit afficher adminGroupId
   ```

5. **Vérifier persistence Firestore**
   ```
   - Ouvrir Firebase Console
   - Collections → group_trackers
   - Vérifier document avec:
     * uid: UID du Compte B
     * adminGroupId: "123456"
     * linkedAdminUid: UID du Compte A
     * displayName: "Compte B" ou vide
     * createdAt: timestamp valide
   
   - Collections → group_positions
   - Vérifier sous-collection créée:
     * group_positions/123456/members/{uid Compte B}
   ```

6. **Vérifier visible dans admin**
   ```
   - Re-login Compte A
   - Aller à /group-admin
   - Observer Compte B dans liste "Trackers liés"
   - Doit afficher:
     * Nom du tracker
     * Statut: "Hors ligne" (initial, pas de position)
   ```

### Résultat attendu

- ✅ Code validé (pas d'erreur)
- ✅ Statut passe à "Rattaché"
- ✅ Document group_trackers créé
- ✅ Sous-collection group_positions créée
- ✅ Visible dans dashboard admin

### Troubleshooting

| Problème | Solution |
|----------|----------|
| Code invalide non détecté | Vérifier GroupLinkService.validateAdminCode() |
| Pas de document group_trackers | Vérifier linkTrackerToAdmin() |
| Permission denied | Vérifier Firestore Rules pour create |
| Tracker non visible admin | Vérifier streamAdminTrackers() |

---

## Test 3: GPS tracking temps réel

**Durée**: 10 minutes
**Dépendances**: Test 2 réussi

### Étapes

1. **Setup device avec GPS**
   ```
   - Sur device physique: Activer GPS
   - Sur émulateur: Simuler position (Android Studio → Extended Controls → Location)
   - Position initiale: ex 45.5, 2.5 (quelque part en France)
   ```

2. **Demander permission GPS**
   ```
   - App doit demander: "Allow location access"
   - Cliquer "Allow" (ou "Allow once")
   - Vérifier que Geolocator reçoit positions
   ```

3. **Lancer tracking depuis admin**
   ```
   - Login Compte A
   - Aller à /group-admin
   - Observer liste trackers: "Compte B - Hors ligne"
   - Cliquer bouton "Commencer tracking"
   - État passe à "En suivi"
   ```

4. **Générer positions**
   ```
   - Avec Compte B (device), simuler mouvement:
     * Distance > 5m (filtre Geolocator)
     * Attendre 5-10 secondes
     * Simuler nouvelle position (45.50005, 2.50005)
   ```

5. **Vérifier positions écrites Firestore**
   ```
   - Ouvrir Firebase Console
   - Collections → group_positions
   - Aller à: group_positions/123456/members/{uid Compte B}
   - Vérifier document lastPosition:
     * lat: 45.50005
     * lng: 2.50005
     * ts: timestamp récent
     * accuracy: <= 50
   
   - Collections → group_tracks
   - Aller à: group_tracks/{adminGroupId}/sessions/{sessionId}
   - Vérifier sous-collection points:
     * Doit avoir 1+ documents
     * Chaque point: {lat, lng, alt, accuracy, ts}
   ```

6. **Vérifier admin voit tracker actif**
   ```
   - Refresh page admin /group-admin
   - Observer "Compte B - Online" ou "5 sec ago"
   - Dernière position affichée
   ```

### Résultat attendu

- ✅ Permission GPS accordée
- ✅ Positions écrites dans group_positions
- ✅ Session créée dans group_tracks
- ✅ Points historiques dans sous-collection
- ✅ Admin voit tracker actif

### Troubleshooting

| Problème | Solution |
|----------|----------|
| Permission GPS refusée | Vérifier manifest Android/Info.plist iOS |
| Positions non écrites | Vérifier GroupTrackingService.startTracking() |
| Pas de session créée | Vérifier document creation dans group_tracks |
| Accuracy > 50m | Vérifier GPS ou émulateur settings |

---

## Test 4: Position moyenne calculée (Cloud Function)

**Durée**: 10 minutes
**Dépendances**: Test 3 réussi

### Étapes

1. **Setup 2 trackers**
   ```
   - Compte B: Position 1 → lat: 45.5001, lng: 2.5001
   - Compte C: Position 2 → lat: 45.5003, lng: 2.5003
   - Moyenne attendue: lat: 45.5002, lng: 2.5002
   ```

2. **Lancer tracking simultané**
   ```
   - Login Compte A
   - Cliquer "Commencer tracking"
   - Login Compte B (device 1), simuler GPS
   - Login Compte C (device 2), simuler GPS différente
   ```

3. **Générer positions simultanées**
   ```
   - Device B: Écrire position1
   - Device C: Écrire position2
   - Attendre 2-3 secondes (Cloud Function trigger)
   ```

4. **Vérifier Cloud Function execution**
   ```
   - Terminal: firebase functions:log
   - Doit voir logs:
     * "Calcul position moyenne pour groupe: 123456"
     * "2 positions valides trouvées"
     * "Position moyenne calculée: 45.5002, 2.5002"
     * "Position moyenne mise à jour avec succès"
   ```

5. **Vérifier averagePosition**
   ```
   - Firebase Console
   - Collections → group_admins
   - Aller au document du Compte A
   - Vérifier averagePosition:
     * lat: ~45.5002
     * lng: ~2.5002
     * ts: timestamp récent
   ```

6. **Vérifier fallback client-side**
   ```
   - Si Cloud Function échoue, client doit calculer fallback
   - Vérifier GroupAverageService.calculateAveragePositionClient()
   - Résultat doit être identique
   ```

### Résultat attendu

- ✅ Cloud Function triggérée
- ✅ averagePosition calculée correctement
- ✅ Logs montrent calcul
- ✅ Fallback client-side fonctionne

### Troubleshooting

| Problème | Solution |
|----------|----------|
| Cloud Function ne trigger pas | Vérifier chemins collection |
| averagePosition null | Vérifier Cloud Function logs |
| Moyenne incorrecte | Vérifier filtering (age, accuracy) |
| Fallback non appelé | Vérifier try/catch dans service |

---

## Test 5: Exports CSV et JSON

**Durée**: 10 minutes
**Dépendances**: Test 3 réussi (session avec points)

### Étapes

1. **Générer session avec points**
   ```
   - Depuis Test 3, avoir:
     * Session: 10+ minutes
     * Points: 5+ positions enregistrées
     * Distance totale: 500m+
   ```

2. **Aller à export page**
   ```
   - Login Compte A (admin)
   - Cliquer menu → "Exports" ou /group-export
   - Doit voir liste sessions
   ```

3. **Sélectionner session**
   ```
   - Dropdown showing sessions
   - Format: "2025-02-04 14:30 - 14:45 (500m)"
   - Sélectionner session du Test 3
   ```

4. **Exporter CSV**
   ```
   - Cliquer bouton "Export CSV"
   - Télécharger fichier (ex: tracking_20250204_143000.csv)
   - Ouvrir fichier texte:
   
   Expected format:
   ```
   date,distance_m,duration_sec,ascent_m,descent_m,avg_speed_mps
   2025-02-04 14:30:00,523.45,900,12.5,8.3,0.58
   ```
   
   Vérifications:
   - Header présent
   - Distance calculée (Haversine entre points)
   - Duration = endTime - startTime (en secondes)
   - Ascent = sum(altitude gains)
   - Descent = sum(altitude losses)
   - Speed = distance / duration
   ```

5. **Exporter JSON**
   ```
   - Clicker bouton "Export JSON"
   - Télécharger fichier (ex: tracking_20250204_143000.json)
   - Ouvrir et vérifier structure:
   
   {
     "sessionId": "abc123",
     "startedAt": "2025-02-04T14:30:00Z",
     "endedAt": "2025-02-04T14:45:00Z",
     "summary": {
       "distance_m": 523.45,
       "duration_sec": 900,
       "ascent_m": 12.5,
       "descent_m": 8.3,
       "avg_speed_mps": 0.58
     },
     "points": [
       {"lat": 45.5001, "lng": 2.5001, "alt": 100, "ts": "..."},
       ...
     ]
   }
   ```

6. **Tester share/download**
   ```
   - Cliquer "Share" ou "Download"
   - Vérifier que fichier s'ouvre ou se télécharge
   - Vérifier sur device physique (Android/iOS)
   ```

### Résultat attendu

- ✅ CSV généré avec bon format
- ✅ JSON généré avec bonne structure
- ✅ Distance calculée correctement (Haversine)
- ✅ Duration en secondes
- ✅ Elevation gains/losses
- ✅ Share/Download fonctionne
- ✅ Cross-platform (web + mobile)

### Troubleshooting

| Problème | Solution |
|----------|----------|
| CSV ne télécharge pas | Vérifier GroupDownloadService |
| Données manquantes | Vérifier group_tracks/{sessionId}/points |
| Distance incorrecte | Vérifier Haversine formula |
| Web ne télécharge pas | Vérifier group_download_web.dart |

---

## Test 6: Permissions GPS (Platform spécifique)

**Durée**: 5 minutes
**Dépendances**: Aucune

### Android

1. **Manifest check**
   ```
   File: app/android/app/src/main/AndroidManifest.xml
   Vérifier présence:
   - <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   - <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   ```

2. **Runtime permissions**
   ```
   - Lancer app sur device Android 6+
   - Première page: "Allow location access?"
   - Cliquer "Allow"
   - Vérifier que GPS actif
   ```

3. **Settings check**
   ```
   - Settings → Apps → masslive → Permissions
   - Location: "Allow only while using the app"
   ```

### iOS

1. **Info.plist check**
   ```
   File: app/ios/Runner/Info.plist
   Vérifier présence:
   - NSLocationWhenInUseUsageDescription
   - Value: "Nous avons besoin de votre position..."
   ```

2. **Runtime permissions**
   ```
   - Lancer app sur device iOS
   - First run: "masslive would like your location"
   - Cliquer "Allow While Using"
   - Vérifier que GPS actif
   ```

3. **Settings check**
   ```
   - Settings → Privacy → Location Services
   - masslive: "While Using"
   ```

### Web

```
- Web ne demande permission GPS
- Mais peut utiliser geolocation API si user approuve
- Geolocator package sur web utilise browser geolocation
```

### Résultat attendu

- ✅ Android manifest OK
- ✅ iOS Info.plist OK
- ✅ Runtime permission prompts
- ✅ User can grant/deny
- ✅ Geolocator reçoit positions après grant

### Troubleshooting

| Problème | Solution |
|----------|----------|
| Pas de prompt | Vérifier manifest/Info.plist |
| GPS ne fonctionne pas | Vérifier Geolocator config (5m filter) |
| Accuracy trop mauvaise | Vérifier GPS settings (not in buildings) |

---

## Test 7: Carte live avec position moyenne

**Durée**: 10 minutes
**Dépendances**: Test 4 réussi (averagePosition calculée)

### Étapes

1. **Navigation vers carte live**
   ```
   - Login Compte A (admin)
   - Cliquer menu → "Carte" ou /group-live
   - Page GroupMapLivePage doit charger
   ```

2. **Carte affichée**
   ```
   - Vérifier que Mapbox/FlutterMap charge
   - Map visible avec pays/régions
   - Zoom initial approprié (France)
   ```

3. **Marqueur position moyenne**
   ```
   - Observer 1 marqueur unique sur carte
   - Position: lat/lng de averagePosition
   - Couleur: verte ou identifiable
   - Label optionnel: "Groupe" ou adminGroupId
   ```

4. **Update temps réel**
   ```
   - Simuler nouveau mouvement trackers
   - Attendre Cloud Function (2-3 sec)
   - Observer marqueur se déplacer sur carte
   - Pas de création de nouveau marqueur
   ```

5. **Zoom/Pan**
   ```
   - Pinch zoom sur carte (mobile) ou scroll (web)
   - Pan vers autre région
   - Marqueur reste visible et suivi
   ```

6. **Vérifier selectedMapId**
   ```
   - Admin peut changer map depuis dashboard
   - /group-live doit afficher map sélectionné
   - Dropdown options: "Mapbox", "Default", etc
   ```

### Résultat attendu

- ✅ Carte charge avec Mapbox/FlutterMap
- ✅ 1 marqueur unique = position moyenne
- ✅ Marqueur se met à jour en temps réel
- ✅ Zoom/Pan fonctionne
- ✅ Map selection fonctionne

### Troubleshooting

| Problème | Solution |
|----------|----------|
| Carte vide | Vérifier Mapbox token (dart-define) |
| Pas de marqueur | Vérifier StreamBuilder → averagePosition |
| Marqueur stuck | Vérifier Cloud Function logs |
| Performance lente | Vérifier tiles Mapbox chargement |

---

## Test 8: Statistiques bar chart

**Durée**: 5 minutes
**Dépendances**: Test 3 réussi (3+ sessions)

### Étapes

1. **Générer sessions multiples**
   ```
   - Avoir 3+ sessions enregistrées
   - Chaque session: 5+ minutes
   - Session 1: 500m, 10 min
   - Session 2: 800m, 15 min
   - Session 3: 300m, 5 min
   ```

2. **Aller à page stats**
   ```
   - Login Compte A (admin)
   - Cliquer menu → "Statistiques" ou /group-stats
   - Page GroupStatsPage doit charger
   ```

3. **Bar chart affiché**
   ```
   - X-axis: Sessions (date/time)
   - Y-axis left: Distance (km)
   - Y-axis right: Duration (minutes)
   - 3 bars visibles
   ```

4. **Vérifier données**
   ```
   - Bar 1: Distance ~0.5km, Duration ~10min
   - Bar 2: Distance ~0.8km, Duration ~15min
   - Bar 3: Distance ~0.3km, Duration ~5min
   - Colors: Différents pour distance vs duration
   ```

5. **Interactif**
   ```
   - Tap sur bar: doit afficher valeurs
   - Scroll horizontal: voir plus sessions
   - Responsive: rotate device → chart adapte
   ```

### Résultat attendu

- ✅ FL_CHART renders correctly
- ✅ Données correctes sur axes
- ✅ Colors distinguent distance/duration
- ✅ Interactivité fonctionne
- ✅ Responsive design

### Troubleshooting

| Problème | Solution |
|----------|----------|
| Chart vide | Vérifier sessions créées |
| Données incorrectes | Vérifier calcul distance/duration |
| Chart ne responsive | Vérifier LayoutBuilder |
| Performance lente | Vérifier nombre sessions |

---

## Résumé tests

| # | Test | Status | Durée |
|---|------|--------|-------|
| 1 | Admin code généré | ⏳ | 5 min |
| 2 | Tracker rattachement | ⏳ | 5 min |
| 3 | GPS tracking | ⏳ | 10 min |
| 4 | Position moyenne | ⏳ | 10 min |
| 5 | Exports CSV/JSON | ⏳ | 10 min |
| 6 | Permissions GPS | ⏳ | 5 min |
| 7 | Carte live | ⏳ | 10 min |
| 8 | Bar chart stats | ⏳ | 5 min |
| | **TOTAL** | **⏳** | **60 min** |

---

## Notes importantes

1. **Ordre des tests**: Respecter l'ordre (1→8) car dépendances
2. **Cleanup**: Entre chaque test, nettoyer Firestore (optionnel)
3. **Devices**: Tester sur Android + iOS + Web si possible
4. **Network**: Tester avec bonne connexion (pas 3G faible)
5. **Bugs**: Documenter tout problème dans GitHub Issues

---

## Après tous les tests

✅ Tous les tests réussis?
→ System ready for production!

❌ Certains tests échouent?
→ Voir troubleshooting + firebase functions:log

🎉 Félicitations! Système de tracking groupe opérationnel!
