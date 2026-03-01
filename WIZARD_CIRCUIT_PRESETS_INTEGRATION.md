# Intégration Système de Presets et Historique - Wizard Circuit

## 📋 Résumé

Ajout d'un système de presets historiques avec onglets dans l'étape publication du wizard circuit, permettant de sauvegarder des versions nommées et de visualiser un log des modifications.

## ✅ Fichiers Créés

1. **`app/lib/services/circuit_preset_service.dart`** ✅
   - Service pour gérer les presets (sauvegarder, lister, charger, supprimer)
   - Génération de changelog (différences entre versions)
   - Formatage lisible du changelog

2. **`app/lib/admin/widgets/circuit_preset_history.dart`** ✅
   - Widget pour afficher l'historique des presets
   - Liste avec cartes interactives
   - Actions: Restaurer, Comparer, Supprimer
   - Support timeago pour dates relatives

3. **`app/lib/admin/widgets/circuit_changelog_viewer.dart`** ✅
   - Widget pour afficher le log des modifications
   - Comparaison visuelle avant/après
   - Icônes et couleurs par type de changement

## ✅ Modifications Effectuées

### 1. `app/pubspec.yaml` ✅
Ajout dépendance:
```yaml
  timeago: ^3.7.0  # Format des dates relatives
```

### 2. `app/lib/admin/circuit_wizard_pro_page.dart` ✅ (partiel)

#### Imports ajoutés:
```dart
import '../services/circuit_preset_service.dart';
import 'widgets/circuit_preset_history.dart';
import 'widgets/circuit_changelog_viewer.dart';
```

#### Variables d'état ajoutées:
```dart
// Publication: onglets et presets
int _publicationTabIndex = 0;
final CircuitPresetService _presetService = CircuitPresetService();
Map<String, dynamic>? _lastPublishedData;
```

#### Fonctions ajoutées:
- `Future<void> _createPreset()` - Créer un nouveau preset
- `Future<void> _restorePreset(Map<String, dynamic> data, String presetName)` - Restaurer un preset

## ⚠️ Modifications Restantes

### Fonction `_buildStep8Publish()` à remplacer

**Ligne 4554 dans circuit_wizard_pro_page.dart**

Remplacer la fonction actuelle par:

```dart
Widget _buildStep8Publish() {
  final report = _qualityReport;
  
  return DefaultTabController(
    length: 2,
    initialIndex: _publicationTabIndex,
    child: Column(
      children: [
        Material(
          color: Colors.transparent,
          child: TabBar(
            onTap: (index) {
              setState(() => _publicationTabIndex = index);
            },
            tabs: const [
              Tab(
                icon: Icon(Icons.cloud_upload),
                text: 'Publication',
              ),
              Tab(
                icon: Icon(Icons.history),
                text: 'Historique',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _buildPublicationTab(report),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildPublicationTab(PublishQualityReport report) {
  return GlassScrollbar(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Publication',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Informations du circuit
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Votre circuit est prêt !',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nom: ${_nameController.text.trim()}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Points périmètre: ${_perimeterPoints.length}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Points tracé: ${_routePoints.length}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Score qualité: ${report.score}/100',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          
          if (!report.canPublish) ...[
            const SizedBox(height: 12),
            const Text(
              '❌ Publication bloquée: corrige les points requis de l'étape Pré-publication.',
              style: TextStyle(color: Colors.redAccent),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Log des modifications
          if (_lastPublishedData != null) ...[
            CircuitChangelogViewer(
              oldData: _lastPublishedData!,
              newData: _buildCurrentData(),
              title: 'Modifications depuis le dernier preset',
            ),
            const SizedBox(height: 24),
          ],
          
          // Bouton créer un preset
          OutlinedButton.icon(
            icon: const Icon(Icons.bookmark_add),
            onPressed: _projectId != null ? _createPreset : null,
            label: const Text('Sauvegarder comme preset'),
          ),
          
          const SizedBox(height: 32),
          const Text(
            'Options de publication',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            onPressed: (report.canPublish && !_isEnsuringAllPoisLoaded)
                ? _publishCircuit
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
            ),
            label: const Text(
              'PUBLIER LE CIRCUIT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          if (_isEnsuringAllPoisLoaded) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chargement de tous les POIs avant publication…',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.save_alt),
            onPressed: () => _saveDraft(createSnapshot: true),
            label: const Text('Rester en brouillon'),
          ),
        ],
      ),
    ),
  );
}

Widget _buildHistoryTab() {
  if (_projectId == null) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Sauvegarde d\'abord le projet\npour accéder à l\'historique',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  return CircuitPresetHistory(
    projectId: _projectId!,
    currentData: _buildCurrentData(),
    onRestore: _restorePreset,
  );
}
```

## 📐 Structure Firestore

Les presets sont sauvegardés dans:

```
map_projects/{projectId}/presets/{presetId}
  - projectId: string
  - name: string
  - description: string
  - createdAt: Timestamp
  - createdBy: string (uid)
  - data: Map (toutes les données du circuit)
  - version: int
```

## 🎯 Fonctionnalités Implémentées

### Onglet Publication
✅ Résumé du circuit (nom, points, score)  
✅ Log des modifications depuis le dernier preset  
✅ Bouton "Sauvegarder comme preset"  
✅ Bouton "Publier le circuit"  
✅ Bouton "Rester en brouillon"  

### Onglet Historique
✅ Liste des presets sauvegardés  
✅ Cartes avec version, nom, description, date  
✅ Informations: nombre de points, POIs, layers  
✅ Menu contextuel:  
  - Restaurer la version  
  - Voir les différences avec l'état actuel  
  - Supprimer le preset  
✅ Message si aucun preset  
✅ Message si projet non sauvegardé  

### Changelog
✅ Détection automatique des modifications  
✅ Comparaison visuelle avant/après  
✅ Icônes par type de champ  
✅ Couleurs (rouge=avant, vert=après)  
✅ Affichage compact dans ExpansionTile  

## 🔄 Workflow Utilisateur

1. **Créer un preset**:
   - Cliquer sur "Sauvegarder comme preset"
   - Entrer un nom (ex: "Version initiale", "Avant ajout POIs")
   - Optionnel: ajouter description
   - Confirmer

2. **Consulter historique**:
   - Aller dans l'onglet "Historique"
   - Voir la liste des presets sauvegardés
   - Tri chronologique (plus récent en premier)

3. **Restaurer une version**:
   - Dans l'onglet "Historique"
   - Menu ⋮ → "Restaurer"
   - Confirmer
   - Le circuit revient à l'état du preset

4. **Comparer versions**:
   - Menu ⋮ → "Voir différences"
   - Dialog avec liste détaillée des changements

5. **Voir modifications en cours**:
   - Onglet "Publication"
   - Section "Modifications depuis le dernier preset"
   - Liste expandable des changements

## 🧪 Tests à Effectuer

1. **Créer un preset**:
   - Vérifier que le dialog s'affiche
   - Créer avec nom uniquement
   - Créer avec nom + description
   - Vérifier message de confirmation

2. **Onglet historique**:
   - Vérifier liste vide (message approprié)
   - Vérifier liste avec plusieurs presets
   - Vérifier formatage des dates
   - Vérifier informations (points, POIs, layers)

3. **Restauration**:
   - Modifier le circuit
   - Restaurer un ancien preset
   - Vérifier que données sont restaurées
   - Vérifier message de confirmation

4. **Comparaison**:
   - Modifier plusieurs champs
   - Comparer avec un preset
   - Vérifier que toutes les différences sont listées
   - Vérifier formatage avant/après

5. **Changelog publication**:
   - Créer un preset
   - Modifier le circuit
   - Vérifier que le changelog s'affiche
   - Vérifier que les modifications sont correctes

6. **Suppression**:
   - Supprimer un preset
   - Vérifier confirmation
   - Vérifier que le preset disparaît

## 📦 Dépendances Ajoutées

```yaml
timeago: ^3.7.0
```

Installation:
```bash
cd app
flutter pub get
```

## 🚀 Déploiement

1. Installer la dépendance:
   ```bash
   cd /workspaces/MASLIVE/app
   flutter pub get
   ```

2. Remplacer la fonction `_buildStep8Publish()` dans `circuit_wizard_pro_page.dart`

3. Tester en local:
   ```bash
   flutter run -d web-server
   ```

4. commit et Push:
   ```bash
   git add .
   git commit -m "feat(wizard): ajouter système presets et historique à l'étape publication"
   git push
   ```

5. Deploy:
   ```bash
   ./commit_push_build_deploy.sh
   ```

## 📝 Notes Techniques

### Cache et Performance
- Les presets sont chargés à la demande (pas de préchargement)
- Limit de 50 presets par projet
- Utilisation de pagination possible si nécessaire

### Sécurité
- Seuls les admins peuvent restaurer  
- Tous les utilisateurs peuvent voir l'historique
- TODOFutur: ajouter permissions granulaires

### Optimisations Possibles
- [ ] Pagination pour +50 presets
- [ ] Recherche/filtre dans l'historique
- [ ] Export presetsen JSON
- [ ] Import presets depuis fichier
- [ ] Comparaison entre 2 presets (pas seulement avec état actuel)
- [ ] Tags/catégories pour presets

---

**Auteur:** GitHub Copilot (Claude Sonnet 4.5)  
**Date:** Mars 2026  
**Version:** 1.0.0
