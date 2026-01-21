# Système de contrôle d'accès pour les cartes pré-enregistrées

## 📋 Résumé des modifications

Un système de permissions a été implémenté pour contrôler l'accès aux commandes de sélection de cartes pré-enregistrées. **Seuls les superadmins** peuvent modifier la sélection des cartes et des couches. Les autres utilisateurs ont accès en **lecture seule** (consultation).

## 🔐 Hiérarchie des permissions

### Superadmins (Admins)
✅ **Peuvent:**
- Ouvrir le sélecteur de cartes
- Sélectionner une carte
- Activer/désactiver les couches
- Appliquer les changements

✅ **Condition:** 
- `role == 'superAdmin'` OU `role == 'superadmin'` OU (`isAdmin == true` ET `role == 'admin'`)

### Utilisateurs normaux
❌ **Ne peuvent PAS:**
- Accéder au bouton "Cartes" (masqué du menu)

⚠️ **Peuvent (si accès direct):**
- Consulter la carte actuellement affichée
- Voir les couches sélectionnées
- Mode lecture seule (checkboxes désactivées, boutons read-only)

## 📁 Fichiers modifiés

### 1. `permission_service.dart`
**Ajout:**
- Méthode `isCurrentUserSuperAdmin()` pour vérifier le statut de superadmin

```dart
Future<bool> isCurrentUserSuperAdmin(String userId) async {
  // Vérifie role == 'superAdmin' OU isAdmin + role 'admin'
}
```

### 2. `map_selector_page.dart`
**Modifications:**
- Ajout du paramètre `isReadOnly` au constructeur
- Mode consultation pour utilisateurs non-superadmins
- Désactivation des interactions (sélection, checkboxes)
- Affichage d'en-tête différent ("Carte active" vs "Sélectionner une carte")
- Bouton "Appliquer" → "Fermer" en mode lecture seule

**Classes modifiées:**
- `MapSelectorPage` : Ajout `isReadOnly` parameter
- `_PresetCard` : Gestion du mode read-only
- `_LayerTile` : Checkboxes désactivées en mode read-only

### 3. `home_map_page.dart`
**Modifications:**
- Chargement du statut superadmin au démarrage
- Bouton "Cartes" masqué pour non-superadmins (condition `if (_isSuperAdmin)`)
- Passage du mode read-only au MapSelectorPage

**Variables ajoutées:**
```dart
bool _isSuperAdmin = false;  // Statut de l'utilisateur
```

**Méthode modifiée:**
```dart
Future<void> _loadUserGroupId() {
  // Charge également le statut superadmin
}
```

## 🔄 Flux d'exécution

### Démarrage de HomeMapPage
```
1. initState() → _loadUserGroupId()
   ↓
2. Récupère le document utilisateur Firestore
   ↓
3. Vérifie si role == 'superAdmin' ou (isAdmin && role == 'admin')
   ↓
4. Définit _isSuperAdmin = true/false
   ↓
5. Affiche/masque le bouton "Cartes" selon _isSuperAdmin
```

### Ouverture du MapSelectorPage
```
1. Utilisateur clique sur "Cartes"
   ↓
2. _openMapSelector() est appelée
   ↓
3. MapSelectorPage s'ouvre avec isReadOnly = !_isSuperAdmin
   ↓
4a. Superadmin → Mode édition (sélection + checkboxes actifs)
4b. Utilisateur normal → Mode lecture seule (consultation)
```

## 🎨 Comportements différents

### Superadmin
```
✅ Bouton "Cartes" visible dans le menu
✅ Peut sélectionner une carte
✅ Peut toggle les couches
✅ Bouton "Appliquer" active
✅ En-tête: "Sélectionner une carte"
```

### Utilisateur normal
```
❌ Bouton "Cartes" masqué du menu
⚠️ Si accès direct → Mode consultation uniquement
❌ Sélection désactivée
❌ Checkboxes désactivées
✅ Bouton "Fermer" (lecture seule)
✅ En-tête: "Carte active"
```

## 🧪 Points de test

- [ ] Vérifier que les superadmins voient le bouton "Cartes"
- [ ] Vérifier que les utilisateurs normaux NE voient PAS le bouton
- [ ] Vérifier que les superadmins peuvent modifier la sélection
- [ ] Vérifier que les utilisateurs en mode read-only voient un message
- [ ] Vérifier que les checkboxes sont désactivés en mode read-only
- [ ] Vérifier que le bouton devient "Fermer" en mode read-only
- [ ] Vérifier que l'en-tête change selon le mode

## 📝 Notes importantes

### Détection du superadmin
La logique teste **trois conditions** pour identifier un superadmin:
1. `role == 'superAdmin'` (casse spécifique)
2. `role == 'superadmin'` (fallback minuscule)
3. `isAdmin == true` ET `role == 'admin'` (admin legacy)

Cela assure la compatibilité avec différents formats de données.

### Sécurité
⚠️ **Important:** Cette implémentation est au niveau **UI/UX**. Pour la sécurité complète:
- Les mutations Firestore doivent être protégées par des regles de sécurité
- Voir `firestore.rules` pour les restrictions au niveau base de données
- La vérification du superadmin en UI prévient les accidents, pas les attaques

### Performance
- Le statut de superadmin est chargé **une seule fois** au démarrage
- Pas de requête répétée si le statut ne change pas
- Les interactions désactivées en mode read-only (pas de logique, juste UI)

## 🚀 Utilisation

### Pour les développeurs

**Ouvrir MapSelectorPage pour superadmin:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MapSelectorPage(
      groupId: 'group_id',
      initialPreset: currentPreset,
      isReadOnly: false,  // Superadmin
      onMapSelected: (preset, layers) { ... },
    ),
  ),
);
```

**Ouvrir MapSelectorPage pour utilisateur normal:**
```dart
// Même code, mais isReadOnly = true
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MapSelectorPage(
      groupId: 'group_id',
      initialPreset: currentPreset,
      isReadOnly: true,   // Utilisateur normal
      onMapSelected: (preset, layers) { ... },
    ),
  ),
);
```

## ✅ Validation

Tous les fichiers compilent sans erreurs:
- ✅ `home_map_page.dart`
- ✅ `map_selector_page.dart`
- ✅ `permission_service.dart`

## 🎯 Résultat final

**Les utilisateurs voient maintenant:**
- 👨‍💼 Superadmin : Menu avec "Cartes" → Peut changer la carte et ses couches
- 👤 Utilisateur : Menu SANS "Cartes" → Ne peut pas modifier, mais voit la carte si elle est déjà active
