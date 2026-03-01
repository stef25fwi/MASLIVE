# 🧪 Checklist de Test - Transparence Immeubles 3D

## Préparation

- [ ] Flutter web lancé (`flutter run -d web-server`)
- [ ] Console développeur ouverte (F12)
- [ ] Page wizard Style Pro accessible
- [ ] Un circuit de test créé/chargé

---

## 🎨 Test 1 : Interface UI (5 min)

### Affichage du widget

- [ ] Le widget "Transparence immeubles" apparaît dans RouteStyleControlsPanel
- [ ] L'icône bâtiment est visible
- [ ] Le switch "Activer immeubles 3D" est présent
- [ ] Le slider d'opacité est visible
- [ ] Les 5 chips preset sont affichés (Opaque, Confort, Équilibré, Léger, Ghost)
- [ ] Le bouton "Réinitialiser" est présent
- [ ] Le tooltip "?" affiche l'explication au survol

### États visuels

- [ ] Quand le switch est OFF → slider est grisé (disabled)
- [ ] Quand le switch est ON → slider est actif
- [ ] Le preset actif a un background de couleur primaire
- [ ] Le pourcentage s'affiche à côté de l'icône bâtiment

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :** 

---

## 🖱️ Test 2 : Interactions Slider (5 min)

### Fonctionnement du slider

- [ ] Déplacer le slider de 0% à 100%
- [ ] Le pourcentage affiché se met à jour en temps réel
- [ ] Les bâtiments 3D deviennent plus/moins transparents **en temps réel**
- [ ] Pas de lag perceptible lors du déplacement
- [ ] Le slider reste fluide même avec déplacement rapide

### Valeurs limites

- [ ] Slider à 0% → bâtiments complètement invisibles
- [ ] Slider à 100% → bâtiments complètement opaques
- [ ] Slider à 50% → bâtiments semi-transparents

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 🎯 Test 3 : Presets Rapides (3 min)

### Clic sur chaque preset

- [ ] Clic sur "Ghost" (20%) → opacité à 20%, preset mis en évidence
- [ ] Clic sur "Léger" (35%) → opacité à 35%, preset mis en évidence
- [ ] Clic sur "Équilibré" (55%) → opacité à 55%, preset mis en évidence
- [ ] Clic sur "Confort" (70%) → opacité à 70%, preset mis en évidence
- [ ] Clic sur "Opaque" (100%) → opacité à 100%, preset mis en évidence

### Preset actif

- [ ] Le preset correspondant à la valeur actuelle est visuellement marqué
- [ ] Quand on utilise le slider, le preset se met à jour automatiquement
- [ ] Quand on clique un preset, il devient actif immédiatement

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 🔀 Test 4 : Toggle Enable/Disable (3 min)

### Activation/Désactivation

- [ ] Régler opacité à 50%
- [ ] Désactiver le switch → bâtiments disparaissent complètement
- [ ] Slider devient grisé (non cliquable)
- [ ] Presets deviennent grisés (non cliquables)
- [ ] Réactiver le switch → bâtiments réapparaissent à 50%
- [ ] Slider redevient actif
- [ ] Presets redeviennent actifs

### Cohérence

- [ ] L'opacité est conservée lors du toggle ON/OFF
- [ ] Pas de crash ou erreur dans la console

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 🔄 Test 5 : Bouton Réinitialiser (2 min)

### Fonctionnement

- [ ] Modifier l'opacité à 25%
- [ ] Cliquer sur "Réinitialiser"
- [ ] L'opacité revient à 60% (valeur par défaut)
- [ ] Le slider se repositionne à 60%
- [ ] Le preset "Équilibré" est mis en évidence (car proche de 60%)

### Cas limites

- [ ] Si déjà à 60%, le bouton ne fait rien mais ne crash pas
- [ ] Si switch OFF, le bouton est cliquable et réinitialise à 60%

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 💾 Test 6 : Persistance (5 min)

### Sauvegarde et rechargement

- [ ] Régler opacité à 40%
- [ ] Cliquer sur "Enregistrer" dans le wizard
- [ ] Naviguer ailleurs (ex: page d'accueil)
- [ ] Revenir sur le circuit → opacité est toujours à 40%
- [ ] Fermer et rouvrir le navigateur → opacité est toujours à 40%

### Firestore

- [ ] Vérifier dans Firestore Console :
  ```
  circuits/{circuitId}/routeStylePro/buildingOpacity = 0.4
  circuits/{circuitId}/routeStylePro/buildings3dEnabled = true
  ```

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 🗺️ Test 7 : Changement de Style Mapbox (5 min)

### Réapplication après changement

- [ ] Régler opacité à 50%
- [ ] Changer le style Mapbox (ex: Streets → Outdoors)
- [ ] Attendre le chargement du nouveau style
- [ ] ✅ L'opacité à 50% est **réappliquée automatiquement**
- [ ] Vérifier dans la console les logs : `[BuildingsOpacity] apply opacity=0.50 layer=... success`

### Test avec réglages différents

- [ ] Toggle OFF les bâtiments
- [ ] Changer le style Mapbox
- [ ] Les bâtiments restent cachés (pas de réapparition)

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## ⚠️ Test 8 : Fallback Gracieux (3 min)

### Style sans bâtiments 3D

- [ ] Charger un style Mapbox **sans** couche 3D (ex: certains styles simples)
- [ ] ✅ Aucune erreur visible dans l'UI
- [ ] ✅ Aucune erreur JavaScript dans la console
- [ ] Logs affichent : `[BuildingsOpacity] no fill-extrusion layer found in current style`
- [ ] Le widget reste affiché mais sans effet

### Comportement

- [ ] Le slider reste fonctionnel (ne crash pas)
- [ ] Quand on revient sur un style avec 3D, l'opacité est appliquée

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 🚀 Test 9 : Performance (5 min)

### Fluidité

- [ ] Déplacer le slider très rapidement de 0 à 100
- [ ] La carte reste fluide (pas de freeze)
- [ ] Les FPS restent > 30 (vérifier avec outils dev)
- [ ] Pas de lag perceptible

### Charge CPU

- [ ] Ouvrir le Task Manager
- [ ] Changer l'opacité plusieurs fois
- [ ] CPU usage reste raisonnable (< 80%)

### Débounce (si implémenté)

- [ ] Si un debounce est présent, vérifier qu'il ne bloque pas l'UI
- [ ] Le changement final est appliqué après relâchement du slider

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 🔍 Test 10 : Console Logs (3 min)

### Logs attendus

Vérifier que ces logs apparaissent dans la console :

#### Au chargement initial
```
[BuildingsOpacity] layer found: 3d-buildings (ou autre)
[BuildingsOpacity] apply opacity=0.60 layer=3d-buildings success
```

#### Lors du changement d'opacité
```
[BuildingsOpacity] layer found: 3d-buildings
[BuildingsOpacity] apply opacity=0.40 layer=3d-buildings success
```

#### Lors du toggle OFF
```
[BuildingsOpacity] layer found: 3d-buildings
[BuildingsOpacity] setBuildingsEnabled visible=false layer=3d-buildings success
```

#### Si pas de couche 3D
```
[BuildingsOpacity] no fill-extrusion layer found in current style
```

- [ ] Tous les logs attendus apparaissent
- [ ] Aucun log d'erreur JavaScript
- [ ] Les logs sont clairs et utiles pour debug

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 🌐 Test 11 : Compatibilité Navigateurs (Web) (10 min)

### Chrome/Chromium

- [ ] Tout fonctionne correctement
- [ ] Pas d'erreur console
- [ ] Performance fluide

### Firefox

- [ ] Tout fonctionne correctement
- [ ] Pas d'erreur console
- [ ] Performance fluide

### Safari (si disponible)

- [ ] Tout fonctionne correctement
- [ ] Pas d'erreur console
- [ ] Performance fluide

### Edge

- [ ] Tout fonctionne correctement
- [ ] Pas d'erreur console
- [ ] Performance fluide

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 📱 Test 12 : Natif (si implémenté) (10 min)

### Android

- [ ] Widget s'affiche correctement
- [ ] Slider fonctionne
- [ ] Opacité change en temps réel
- [ ] Persistance fonctionne
- [ ] Pas de crash

### iOS

- [ ] Widget s'affiche correctement
- [ ] Slider fonctionne
- [ ] Opacité change en temps réel
- [ ] Persistance fonctionne
- [ ] Pas de crash

**Résultat :** ✅ PASS | ❌ FAIL | ⏭️ SKIP (non implémenté)  
**Notes :**

---

## 🔧 Test 13 : Edge Cases (5 min)

### Cas limites

- [ ] Charger un circuit **sans** `routeStylePro` → valeurs par défaut (60%, enabled)
- [ ] Charger un circuit avec `buildingOpacity` à `null` → 60% par défaut
- [ ] Charger un circuit avec `buildingOpacity` à 1.5 → clamped à 1.0
- [ ] Charger un circuit avec `buildingOpacity` à -0.2 → clamped à 0.0
- [ ] Sauvegarder avec opacité 0% → pas d'erreur, sauvegarde 0.0

### Multiples instances

- [ ] Ouvrir 2 onglets avec le même circuit
- [ ] Changer l'opacité dans l'onglet 1
- [ ] Rafraîchir l'onglet 2 → affiche la nouvelle valeur

**Résultat :** ✅ PASS | ❌ FAIL  
**Notes :**

---

## 📊 Récapitulatif Final

| Test | Résultat | Durée | Notes |
|------|----------|-------|-------|
| 1. Interface UI | ☐ PASS ☐ FAIL | __ min | |
| 2. Interactions Slider | ☐ PASS ☐ FAIL | __ min | |
| 3. Presets Rapides | ☐ PASS ☐ FAIL | __ min | |
| 4. Toggle Enable/Disable | ☐ PASS ☐ FAIL | __ min | |
| 5. Bouton Réinitialiser | ☐ PASS ☐ FAIL | __ min | |
| 6. Persistance | ☐ PASS ☐ FAIL | __ min | |
| 7. Changement Style Mapbox | ☐ PASS ☐ FAIL | __ min | |
| 8. Fallback Gracieux | ☐ PASS ☐ FAIL | __ min | |
| 9. Performance | ☐ PASS ☐ FAIL | __ min | |
| 10. Console Logs | ☐ PASS ☐ FAIL | __ min | |
| 11. Navigateurs Web | ☐ PASS ☐ FAIL | __ min | |
| 12. Natif | ☐ PASS ☐ FAIL ☐ SKIP | __ min | |
| 13. Edge Cases | ☐ PASS ☐ FAIL | __ min | |

**Total estimé :** ~60 minutes

---

## 🐛 Bugs Trouvés

| # | Description | Sévérité | Fichier | Action |
|---|-------------|----------|---------|--------|
| 1 | | ☐ Bloquant ☐ Majeur ☐ Mineur | | |
| 2 | | ☐ Bloquant ☐ Majeur ☐ Mineur | | |
| 3 | | ☐ Bloquant ☐ Majeur ☐ Mineur | | |

---

## ✅ Validation Finale

- [ ] Tous les tests passent (ou bugs documentés)
- [ ] Aucun crash ou erreur bloquante
- [ ] Performance acceptable
- [ ] UX fluide et intuitive
- [ ] Logs debug clairs et utiles
- [ ] Documentation lue et comprise

**Testé par :** ________________________  
**Date :** ____________________________  
**Version :** __________________________  

---

## 📝 Notes Additionnelles

Utilisez cet espace pour noter toute observation, suggestion d'amélioration, ou comportement inattendu :

```
...
```

---

## 🚀 Prochaine Étape

Une fois tous les tests passés :

1. **Commiter les changements** :
   ```bash
   git add .
   git commit -m "feat: ajouter contrôle transparence immeubles 3D"
   git push
   ```

2. **Déployer** :
   ```bash
   ./commit_push_build_deploy.sh
   ```

3. **Tester en production** sur quelques circuits réels

4. **Monitorer** les logs Firebase/Sentry pour détecter des erreurs en prod

5. **Communiquer** la nouvelle fonctionnalité aux utilisateurs

---

**Auteur:** GitHub Copilot (Claude Sonnet 4.5)  
**Date:** Mars 2026
