# 🎯 Structure du Dashboard Administrateur MASLIVE

## 📊 Vue d'ensemble

Le **dashboard administrateur** (`AdminMainDashboard`) est maintenant **entièrement réorganisé** avec des sections claires et hiérarchiques pour une gestion efficace de l'application.

**Localisation** : `app/lib/admin/admin_main_dashboard.dart`

---

## 📋 Sections du Dashboard

### 1️⃣ **Carte & Navigation** 🗺️
Outils de gestion cartographique et des itinéraires

| Tuile | Description | Icône | Couleur | Action |
|-------|-------------|-------|--------|--------|
| **Parcours** | Créer et gérer les circuits | 🛣️ Route | Bleu | `AdminCircuitsPage` |
| **Points d'intérêt** | Gérer les POIs (Visiter, Food, WC, etc.) | 📍 Place | Orange | `AdminPOIsSimplePage` |

---

### 2️⃣ **Tracking & Groupes** 📍
Suivi en temps réel et gestion des groupes

| Tuile | Description | Icône | Couleur | Action |
|-------|-------------|-------|--------|--------|
| **Tracking Live** | Suivre les groupes en temps réel | 📍 My Location | Vert | `AdminTrackingPage` |
| **Groupes** | Gérer les groupes (à venir) | 👥 Group | Violet | À venir |

---

### 3️⃣ **Commerce** 🛍️
Gestion du catalogue et des commandes

| Tuile | Description | Icône | Couleur | Action |
|-------|-------------|-------|--------|--------|
| **Produits** | Gérer le catalogue produits | 📦 Inventory | Teal | `AdminProductsPage` |
| **Commandes** | Suivi des commandes (à venir) | 📋 Receipt | Amber | À venir |
| **Test Stripe** | Vérifier la connexion Stripe | 💳 Payment | Violet foncé | Test Stripe Dialog |

---

### 4️⃣ **Utilisateurs** 👥
Gestion des utilisateurs et des rôles

| Tuile | Description | Icône | Couleur | Action |
|-------|-------------|-------|--------|--------|
| **Gestion des utilisateurs** | Créer, modifier, gérer les rôles | 🔐 Admin Panel | Indigo | `UserManagementPage` |

---

### 5️⃣ **Comptes Professionnels** 💼 ✨ NOUVEAU
Gestion des demandes de comptes pros (Stripe Connect)

| Tuile | Description | Icône | Couleur | Action |
|-------|-------------|-------|--------|--------|
| **Demandes Pro** | Valider les demandes de comptes professionnels | 📝 Request Page | Saumon | `BusinessRequestsPage` |

**Fonctionnalités** :
- ✅ Liste des demandes en attente
- ✅ Approbation/Rejet avec motif optionnel
- ✅ Validation avant Stripe Connect Express
- ✅ Synchronisation automatique des statuts Stripe

---

### 6️⃣ **Analytics & Système** 📊
Monitoring, logs et configuration système

| Tuile | Description | Icône | Couleur | Action |
|-------|-------------|-------|--------|--------|
| **Analytics** | Statistiques détaillées | 📊 Bar Chart | Cyan | `AdminAnalyticsPage` |
| **Logs** | Journaux système et audit | 📄 Description | Bleu-gris | `AdminLogsPage` |
| **Paramètres système** | Configuration avancée (Super Admin) | ⚙️ Settings | Rouge | `AdminSystemSettingsPage` |

⚠️ **Paramètres système** : Visible uniquement pour les **Super Admins** (`isSuperAdmin == true`)

---

## 🎨 Design & Responsivité

### Layout
- **Header** : Carte de bienvenue avec info utilisateur (nom, rôle)
- **Sections** : Titre de section avec icône
- **Tuiles** : 
  - Simples (full width) pour les pages principales
  - Grille 2 colonnes pour les groupes connexes
  - Couleurs distinctes par domaine

### Interactions
- Navigation immédiate vers les sous-pages
- SnackBars pour les pages à venir
- Bouton rafraîchir dans l'AppBar

---

## 🔗 Navigation depuis le Menu

L'accès au dashboard admin se fait via :
1. **Page Compte** (`AccountPage`) → Tuile "Espace Administrateur"
2. **Routes nommées** : `/admin` (à configurer dans le routeur)

```dart
// Dans AccountPage ou AccountAdminPage
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AdminMainDashboard(),
  ),
);
```

---

## 📝 Ajout de nouvelles tuiles

Pour ajouter une nouvelle tuile au dashboard :

### 1. Ajouter l'import
```dart
import 'path/to/your_page.dart';
```

### 2. Créer la tuile
```dart
_buildDashboardCard(
  title: 'Nom de la tuile',
  subtitle: 'Description brève',
  icon: Icons.icon_name,
  color: Colors.color,
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const YourPage()),
  ),
)
```

### 3. Placer dans la section appropriée
- Ou créer une nouvelle section si besoin

---

## 🛠️ Méthodes utilitaires

### `_buildSectionTitle(String title, IconData icon)`
Crée un titre de section avec icône et espacement

```dart
_buildSectionTitle('Ma Section', Icons.icon)
```

### `_buildDashboardCard({...})`
Crée une tuile du dashboard avec design uniforme

```dart
_buildDashboardCard(
  title: 'Titre',
  subtitle: 'Sous-titre',
  icon: Icons.icon,
  color: Colors.color,
  onTap: () => { /* action */ },
)
```

### `_buildWelcomeCard()`
Affiche une carte de bienvenue avec info utilisateur

---

## 🔐 Permissions

- **Admin normal** : Accès à toutes les sections sauf "Paramètres système"
- **Super Admin** : Accès complet, y compris "Paramètres système"

Vérification :
```dart
if (_currentUser?.isSuperAdmin == true)
  // Afficher tuile "Paramètres système"
```

---

## 📦 Pages liées

| Page | Fichier | Rôle |
|------|---------|------|
| **AdminCircuitsPage** | `admin_circuits_page.dart` | CRUD circuits |
| **AdminPOIsSimplePage** | `admin_pois_simple_page.dart` | Gestion POIs |
| **AdminTrackingPage** | `admin_tracking_page.dart` | Tracking live |
| **AdminProductsPage** | `admin_products_page.dart` | Gestion catalogue |
| **AdminAnalyticsPage** | `admin_analytics_page.dart` | Statistiques |
| **AdminLogsPage** | `admin_logs_page.dart` | Logs système |
| **AdminSystemSettingsPage** | `admin_system_settings_page.dart` | Config système |
| **UserManagementPage** | `user_management_page.dart` | Gestion utilisateurs |
| **BusinessRequestsPage** | `business_requests_page.dart` | Demandes pro ✨ |

---

## ✅ Checklist d'utilisation

- [ ] Admin accède à **AdminMainDashboard** depuis le menu Compte
- [ ] Dashboard affiche toutes les sections avec les bons icônes et couleurs
- [ ] Les tuiles "Demandes Pro" permettent de valider/rejeter les demandes
- [ ] Les pages liées se chargent correctement
- [ ] Super Admin voit la tuile "Paramètres système"
- [ ] Responsivité testée sur mobile/tablette/desktop

---

## 🚀 Prochaines améliorations

- [ ] Ajouter un **compteur de demandes en attente** sur la tuile "Demandes Pro"
- [ ] Afficher des **statistiques clés** directement sur les tuiles
- [ ] Créer une **page Groupes** complète (gestion créer/éditer/supprimer)
- [ ] Créer une **page Commandes** avec filtrage et export
- [ ] Ajouter des **widgets de monitoring** (uptime, erreurs, etc.)
- [ ] Implémenter un **système de notifications** pour les approbations/rejets
