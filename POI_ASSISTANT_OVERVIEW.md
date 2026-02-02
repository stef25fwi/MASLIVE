# 📍 Assistant POI - Page Step-by-Step

> ⚠️ **Legacy** : cet assistant est remplacé par le Wizard MarketMap.
> Utiliser : `app/lib/admin/poi_marketmap_wizard_page.dart`.

## Vue d'ensemble

L'Assistant POI est une page de gestion des Points d'Intérêt (POI) organisée en 5 étapes guidées, permettant aux administrateurs de créer et configurer des POIs de manière fluide et professionnelle.

## 5 Étapes du Wizard

### ✅ Step 1: Sélectionner une Carte
**Objectif**: Choisir une carte existante dans la bibliothèque

**Fonctionnalités**:
- 📚 Liste des cartes disponibles
- 📋 Affichage: Nom, description, date de modification
- 🎯 Sélection en un clic
- ✓ Validation avec feedback visuel

**Données affichées**:
- ID unique de la carte
- Nom de la carte
- Description
- Date de dernière modification

---

### 📍 Step 2: Charger la Carte
**Objectif**: Afficher la carte sélectionnée en plein écran

**Fonctionnalités**:
- 🗺️ Mapbox GL JS en plein écran
- 📊 Header affichant la carte sélectionnée
- ℹ️ Instructions overlay
- 🔘 Bouton Suivant flottant

**Comportement**:
- Charge la carte Mapbox avec token MAPBOX_ACCESS_TOKEN
- Fallback sur grille si pas de token (développement)
- Zoom et centrage sur la région

---

### 🎨 Step 3: Choisir la Couche
**Objectif**: Sélectionner la couche de travail (layer)

**Fonctionnalités**:
- 🏠 Grille 2 colonnes des couches disponibles
- ✨ Animations au survol
- ✓ Indication visuelle de sélection
- 🔘 Navigation précédent/suivant

**Exemple de couches**:
- Points d'intérêt
- Restaurants
- Hôtels
- Musées
- Boutiques
- Services
- Etc.

---

### ✏️ Step 4: Éditer les POIs
**Objectif**: Ajouter et gérer les POIs de la couche

**Fonctionnalités**:
- ➕ Bouton pour ajouter des POIs
- 🗑️ Supprimer des POIs
- ✏️ Éditer les propriétés (nom, position)
- 📍 Affichage liste complète avec:
  - Icône colorée
  - Nom du POI
  - Coordonnées (lat/lng)

**Actions sur POI**:
- Tap pour éditer le nom
- Swipe/Delete pour supprimer
- Chaque POI a:
  - ID unique (timestamp)
  - Nom
  - Latitude/Longitude
  - Icône par défaut
  - Couleur par défaut

**Dialog d'édition**:
- Champ texte pour le nom
- Affichage des coordonnées
- Aperçu de la couleur

---

### 🎨 Step 5: Configurer l'Apparence
**Objectif**: Personnaliser le rendu visuel de chaque POI

**Fonctionnalités par POI**:

#### Couleur
- 🌈 Palette de 8 couleurs
- Sélection par tap
- Aperçu en temps réel

#### Icône
- 📌 `pin` (épingle)
- ⭐ `star` (étoile)
- ❤️ `heart` (cœur)
- 🚩 `flag` (drapeau)
- Choix via chips

#### Taille
- 📏 Slider de 16px à 40px
- Ajustement en direct
- Label affichant la taille

**Expansion Tile par POI**:
- Clique pour dérouler
- Vue complète de tous les réglages
- Sauvegarde automatique

---

## Architecture

```
POIAssistantPage (StatefulWidget)
├── _POIAssistantPageState
│   ├── _step (0-4)
│   ├── _selectedMapId
│   ├── _selectedLayer
│   ├── _currentPOIs (List<Map>)
│   ├── _autoSaveTimer
│   └── _stepValidated (List<bool>)
│
├── Step Widgets
│   ├── _StepSelectMap
│   ├── _StepLoadMap
│   ├── _StepSelectLayer
│   ├── _StepEditPOIs
│   └── _StepStylePOIs
│
└── Helpers
    ├── _hexToColor()
    ├── _loadDraft()
    ├── _saveDraft()
    └── _formatTime()
```

## Données & État

### POI Structure
```dart
{
  'id': 1234567890,           // timestamp
  'name': 'Restaurant ABC',
  'lat': 16.241,
  'lng': -61.534,
  'icon': 'pin',              // pin, star, heart, flag
  'color': '#FF0000',         // Hex color
  'size': 24                  // pixel size
}
```

### Map Structure
```dart
{
  'id': 'map_1',
  'name': 'Guadeloupe - Attractions',
  'description': '...',
  'layers': ['Points d\'intérêt', 'Restaurants', ...],
  'lastModified': '2025-01-20'
}
```

## Fonctionnalités Avancées

### 💾 Auto-Save
- Sauvegarde toutes les 30 secondes via SharedPreferences
- Récupération du brouillon au démarrage
- Dialog de confirmation

### 🎯 Validation par Étape
- Toggle "Étape validée" en bas
- Affichage du statut dans le sélecteur
- Optionnel mais encouragé

### 🎨 Mode Focus
- Masque les distractions
- Effectif sur tous les écrans
- Toggle en haut à droite

### 📱 Responsive
- Adapté mobile/tablette/desktop
- Grid adaptative pour couches
- Overlays ajustés

## Intégration

### Import
```dart
import 'poi_assistant_page.dart';
```

### Navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const POIAssistantPage(),
  ),
);
```

### Bouton Admin Dashboard
Activé dans `admin_main_dashboard.dart`:
- Titre: "Assistant POI (Wizard)"
- Badge: "New"
- Couleur: Orange (#FF7A00)
- Icône: Icons.place_rounded

---

## Prochaines Étapes (Futures)

- [ ] Connexion à la vraie base de données (Firestore)
- [ ] Médias/Photos pour POIs
- [ ] Clustering de POIs
- [ ] Géolocalisation automatique
- [ ] Validation de données
- [ ] Export/Import
- [ ] Historique de versions
- [ ] Partage de cartes

---

## Fichiers

| Fichier | Rôle |
|---------|------|
| `app/lib/admin/poi_assistant_page.dart` | Page principale + Steps |
| `app/lib/admin/admin_main_dashboard.dart` | Navigation vers POI Assistant |

---

## Statut

✅ **Complété**: Page full fonctionnelle  
✅ **Structure**: 5 étapes bien organisées  
✅ **UI/UX**: Professional et intuitive  
⏳ **Backend**: Prêt pour intégration Firestore  

---

**Créé**: 2025-01-26  
**Version**: 1.0  
**Status**: Production Ready 🚀
