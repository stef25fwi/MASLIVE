// ignore_for_file: unused_field, unused_element, dead_code

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';

import '../ui/widgets/mapbox_web_view_platform.dart';
import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_token_dialog.dart';
import 'poi_marketmap_wizard_page.dart';

// Import conditionnel: mapbox_native_simple_map est pour mobile/desktop uniquement
import '../ui/widgets/mapbox_native_simple_map.dart'
    if (dart.library.html) '../ui/widgets/mapbox_native_simple_map_stub.dart';

/// Assistant step-by-step pour la gestion des POIs
class POIAssistantPage extends StatefulWidget {
  const POIAssistantPage({super.key});

  @override
  State<POIAssistantPage> createState() => _POIAssistantPageState();
}

class _POIAssistantPageState extends State<POIAssistantPage> {
  int _step = 0;
  bool _isFocusMode = false;
  Timer? _autoSaveTimer;
  DateTime? _lastAutoSave;
  String _mapName = '';
  String? _selectedMapId;
  String? _selectedLayer;
  final List<bool> _stepValidated = List<bool>.filled(5, false);

  String _runtimeMapboxToken = '';
  String _mapboxTokenSource = '...';

  String get _effectiveMapboxToken => _runtimeMapboxToken.isNotEmpty
      ? _runtimeMapboxToken
      : MapboxTokenService.getTokenSync();

  // Liste fictive des cartes disponibles
  final List<Map<String, dynamic>> _availableMaps = [
    {
      'id': 'map_1',
      'name': 'Guadeloupe - Attractions',
      'description': 'Carte avec attractions touristiques',
      'layers': ['Points d\'intérêt', 'Restaurants', 'Hôtels', 'Musées'],
      'lastModified': '2025-01-20',
    },
    {
      'id': 'map_2',
      'name': 'Martinique - Commerce',
      'description': 'Carte commerciale et services',
      'layers': ['Boutiques', 'Services', 'Pharmacies', 'Banques'],
      'lastModified': '2025-01-15',
    },
    {
      'id': 'map_3',
      'name': 'Pointe-à-Pitre - Loisirs',
      'description': 'Carte des loisirs et divertissements',
      'layers': ['Cinémas', 'Sports', 'Parcs', 'Événements'],
      'lastModified': '2025-01-10',
    },
  ];

  // POIs actuels
  List<Map<String, dynamic>> _currentPOIs = [];

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _startAutoSave();
    _loadMapboxToken();
  }

  Future<void> _loadMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (!mounted) return;
      setState(() {
        _runtimeMapboxToken = info.token;
        _mapboxTokenSource = info.source;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _configureMapboxToken() async {
    final newToken = await MapboxTokenDialog.show(
      context,
      initialValue: _effectiveMapboxToken,
    );
    if (!mounted || newToken == null) return;
    final info = await MapboxTokenService.getTokenInfo();
    if (!mounted) return;
    setState(() {
      _runtimeMapboxToken = newToken;
      _mapboxTokenSource = info.source;
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveDraft();
    });
  }

  Future<void> _saveDraft({String? mapName}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nameToSave = mapName ?? _mapName;
      final draftData = {
        'step': _step,
        'timestamp': DateTime.now().toIso8601String(),
        'isFocusMode': _isFocusMode,
        'mapName': nameToSave,
        'selectedMapId': _selectedMapId,
        'selectedLayer': _selectedLayer,
        'stepValidated': _stepValidated,
        'pois': _currentPOIs,
      };
      _mapName = nameToSave;
      await prefs.setString('poi_draft', jsonEncode(draftData));
      setState(() {
        _lastAutoSave = DateTime.now();
      });
    } catch (e) {
      debugPrint('Erreur auto-save: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString('poi_draft');
      if (draftJson != null) {
        final draftData = jsonDecode(draftJson);
        final draftTime = DateTime.parse(draftData['timestamp']);
        final isRecent = DateTime.now().difference(draftTime).inHours < 24;

        if (isRecent && mounted) {
          final shouldRestore = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.restore, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Brouillon trouvé'),
                ],
              ),
              content: Text(
                'Un brouillon de POIs a été trouvé (sauvegardé ${_formatTime(draftTime)}).\n\nVoulez-vous continuer ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Recommencer'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Restaurer'),
                ),
              ],
            ),
          );

          if (shouldRestore == true) {
            setState(() {
              _step = draftData['step'] ?? 0;
              _isFocusMode = draftData['isFocusMode'] ?? false;
              _mapName = draftData['mapName'] ?? '';
              _selectedMapId = draftData['selectedMapId'];
              _selectedLayer = draftData['selectedLayer'];
              _currentPOIs = List<Map<String, dynamic>>.from(
                (draftData['pois'] as List?) ?? [],
              );
              final restoredValidated = draftData['stepValidated'];
              if (restoredValidated is List) {
                for (
                  int i = 0;
                  i < _stepValidated.length && i < restoredValidated.length;
                  i++
                ) {
                  final val = restoredValidated[i];
                  if (val is bool) {
                    _stepValidated[i] = val;
                  }
                }
              }
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Brouillon restauré avec succès'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            await prefs.remove('poi_draft');
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur load draft: $e');
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  void _toggleFocusMode() {
    setState(() {
      _isFocusMode = !_isFocusMode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFocusMode
              ? '🎯 Mode focus activé - Distractions masquées'
              : '👁️ Mode normal restauré',
        ),
        backgroundColor: _isFocusMode ? Colors.deepPurple : Colors.grey,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Legacy: redirection vers le Wizard MarketMap (source de vérité).
    return const POIMarketMapWizardPage();
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return '1/5 • Sélectionner une carte';
      case 1:
        return '2/5 • Charger la carte';
      case 2:
        return '3/5 • Choisir la couche';
      case 3:
        return '4/5 • Éditer les POIs';
      case 4:
        return '5/5 • Configurer l\'apparence';
      default:
        return '';
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _StepSelectMap(
          availableMaps: _availableMaps,
          selectedMapId: _selectedMapId,
          onMapSelected: (mapId) {
            setState(() {
              _selectedMapId = mapId;
            });
            _saveDraft();
          },
          onMapDelete: _showDeleteConfirmation,
          onNext: _nextStep,
        );
      case 1:
        return _StepLoadMap(
          selectedMapId: _selectedMapId,
          selectedMapName: _availableMaps.firstWhere(
            (m) => m['id'] == _selectedMapId,
            orElse: () => {},
          )['name'],
          mapboxToken: _effectiveMapboxToken,
          mapboxTokenSource: _mapboxTokenSource,
          onConfigureMapboxToken: _configureMapboxToken,
          onNext: _nextStep,
          onPrev: _prevStep,
        );
      case 2:
        return _StepSelectLayer(
          selectedMapId: _selectedMapId,
          availableMaps: _availableMaps,
          selectedLayer: _selectedLayer,
          onLayerSelected: (layer) {
            setState(() {
              _selectedLayer = layer;
            });
            _saveDraft();
          },
          onNext: _nextStep,
          onPrev: _prevStep,
        );
      case 3:
        return _StepEditPOIs(
          selectedLayer: _selectedLayer,
          pois: _currentPOIs,
          onPOIsChanged: (pois) {
            setState(() {
              _currentPOIs = pois;
            });
            _saveDraft();
          },
          onNext: _nextStep,
          onPrev: _prevStep,
        );
      case 4:
        return _StepStylePOIs(
          selectedLayer: _selectedLayer,
          pois: _currentPOIs,
          onStyleChanged: (pois) {
            setState(() {
              _currentPOIs = pois;
            });
            _saveDraft();
          },
          onPrev: _prevStep,
        );
      default:
        return Container();
    }
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Étape validée',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Switch(
                  value: _stepValidated[_step],
                  onChanged: (val) {
                    setState(() {
                      _stepValidated[_step] = val;
                    });
                    _saveDraft();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: _prevStep,
                    child: const Text('Précédent'),
                  ),
                Row(
                  children: [
                    Text(
                      'Étape ${_step + 1}/5',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    if (_step < 4)
                      ElevatedButton(
                        onPressed: _nextStep,
                        child: const Text('Suivant'),
                      ),
                    if (_step == 4)
                      ElevatedButton(
                        onPressed: _publishPOIs,
                        child: const Text('Publier'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _publishPOIs() async {
    if (_selectedMapId == null || _mapName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Veuillez sélectionner une carte'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Afficher un loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) throw Exception('Non authentifié');

      // Récupérer la carte sélectionnée pour extraire le pays
      final selectedMap = _availableMaps.firstWhere(
        (map) => map['id'] == _selectedMapId,
        orElse: () => {},
      );

      final mapName = selectedMap['name'] as String? ?? _mapName;

      // Extraire le pays du nom (ex: "Guadeloupe - Attractions" -> "Guadeloupe")
      final countryFromName = mapName.contains(' - ')
          ? mapName.split(' - ').first.trim()
          : 'Autre';

      // Créer le document de la carte dans Firestore
      final mapDocRef = db.collection('poi_maps').doc();

      await mapDocRef.set({
        'id': mapDocRef.id,
        'name': mapName,
        'title': _mapName,
        'country': countryFromName,
        'description': 'Carte créée via le wizard POI',
        'poiCount': _currentPOIs.length,
        'pois': _currentPOIs.map((poi) {
          return {
            'name': poi['name'] ?? '',
            'icon': poi['icon'] ?? 'pin',
            'color': poi['color']?.toString() ?? '',
            'type': poi['type'] ?? 'point',
          };
        }).toList(),
        'status': 'draft',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // Fermer le loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Carte sauvegardée dans la bibliothèque !'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () {
              // Naviguer vers la bibliothèque
              Navigator.of(context).pushNamed('/library');
            },
          ),
        ),
      );

      // Attendre 1 seconde puis fermer
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fermer le loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Affiche un dialog de confirmation de suppression de carte avec demande d'écriture "delete"
  void _showDeleteConfirmation(String mapId, String mapName) {
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Supprimer cette carte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir supprimer la carte "$mapName" ?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cette action est irréversible. Tapez "delete" pour confirmer :',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: InputDecoration(
                hintText: 'Tapez "delete"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.warning_amber),
              ),
              textCapitalization: TextCapitalization.none,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              confirmCtrl.dispose();
              Navigator.pop(context);
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: confirmCtrl.text.trim() != 'delete'
                ? null
                : () {
                    confirmCtrl.dispose();
                    Navigator.pop(context);
                    _deleteMap(mapId);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmCtrl.text.trim() == 'delete'
                  ? Colors.red
                  : Colors.grey,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  /// Supprime la carte de la liste
  void _deleteMap(String mapId) {
    setState(() {
      _availableMaps.removeWhere((map) => map['id'] == mapId);
      if (_selectedMapId == mapId) {
        _selectedMapId = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Carte supprimée'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildStepSelector() {
    final steps = ['Sélectionner', 'Charger', 'Couche', 'Éditer', 'Apparence'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(steps.length, (index) {
            final isActive = index == _step;
            final isValidated = _stepValidated[index];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(steps[index]),
                selected: isActive,
                avatar: isValidated
                    ? const Icon(Icons.check_circle, size: 18)
                    : Text('${index + 1}'),
                onSelected: (selected) {
                  setState(() {
                    _step = index;
                  });
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  void _nextStep() {
    setState(() {
      if (_step < 4) _step++;
    });
  }

  void _prevStep() {
    setState(() {
      if (_step > 0) _step--;
    });
  }
}

// Step 1: Sélectionner une carte
class _StepSelectMap extends StatelessWidget {
  final List<Map<String, dynamic>> availableMaps;
  final String? selectedMapId;
  final Function(String) onMapSelected;
  final Function(String, String)? onMapDelete;
  final VoidCallback onNext;

  const _StepSelectMap({
    required this.availableMaps,
    required this.selectedMapId,
    required this.onMapSelected,
    this.onMapDelete,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.cyan.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sélectionnez une carte existante dans la bibliothèque',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: availableMaps.length,
            itemBuilder: (context, index) {
              final map = availableMaps[index];
              final isSelected = map['id'] == selectedMapId;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isSelected ? 4 : 1,
                color: isSelected ? Colors.blue.shade50 : null,
                child: ListTile(
                  leading: Icon(
                    Icons.map,
                    color: isSelected ? Colors.blue : Colors.grey[600],
                  ),
                  title: Text(
                    map['name'],
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        map['description'],
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Modifiée: ${map['lastModified']}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        Icon(Icons.check_circle, color: Colors.blue.shade700),
                      if (isSelected) const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete' && onMapDelete != null) {
                            onMapDelete!(map['id'], map['name']);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Supprimer',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Tooltip(
                          message: 'Options',
                          child: Icon(
                            Icons.more_vert,
                            color: isSelected ? Colors.blue : Colors.grey[600],
                          ),
                        ),
                      ),
                      if (!isSelected) const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    onMapSelected(map['id']);
                  },
                ),
              );
            },
          ),
        ),
        if (selectedMapId != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    availableMaps.firstWhere(
                      (m) => m['id'] == selectedMapId,
                    )['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: onNext,
                  child: const Text('Continuer'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Step 2: Charger la carte en plein écran
class _StepLoadMap extends StatelessWidget {
  final String? selectedMapId;
  final String? selectedMapName;
  final String mapboxToken;
  final String mapboxTokenSource;
  final VoidCallback onConfigureMapboxToken;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _StepLoadMap({
    required this.selectedMapId,
    required this.selectedMapName,
    required this.mapboxToken,
    required this.mapboxTokenSource,
    required this.onConfigureMapboxToken,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (selectedMapName != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade100,
            child: Row(
              children: [
                Icon(Icons.map, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Carte: $selectedMapName',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              // Mapbox en plein écran
              if (mapboxToken.isNotEmpty)
                kIsWeb
                    ? MapboxWebView(
                        accessToken: mapboxToken,
                        initialLat: 16.241,
                        initialLng: -61.534,
                        initialZoom: 11.0,
                        styleUrl: 'mapbox://styles/mapbox/streets-v12',
                      )
                    : MapboxNativeSimpleMap(
                        accessToken: mapboxToken,
                        initialLat: 16.241,
                        initialLng: -61.534,
                        initialZoom: 11.0,
                      )
              else
                Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Mapbox nécessite MAPBOX_ACCESS_TOKEN (ou MAPBOX_TOKEN legacy)',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Source: $mapboxTokenSource',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: onConfigureMapboxToken,
                          icon: const Icon(Icons.vpn_key),
                          label: const Text('Configurer le token'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Instructions overlay
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(242),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fullscreen,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'La carte s\'ouvre en plein écran\nChoisissez la couche ensuite',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Next button
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Suivant'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Step 3: Choisir la couche
class _StepSelectLayer extends StatelessWidget {
  final String? selectedMapId;
  final List<Map<String, dynamic>> availableMaps;
  final String? selectedLayer;
  final Function(String) onLayerSelected;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _StepSelectLayer({
    required this.selectedMapId,
    required this.availableMaps,
    required this.selectedLayer,
    required this.onLayerSelected,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    final map = availableMaps.firstWhere(
      (m) => m['id'] == selectedMapId,
      orElse: () => {},
    );
    final layers = (map['layers'] as List<dynamic>?)?.cast<String>() ?? [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade50, Colors.pink.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.layers, color: Colors.purple.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sélectionnez la couche sur laquelle travailler',
                  style: TextStyle(fontSize: 13, color: Colors.purple.shade900),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: layers.length,
            itemBuilder: (context, index) {
              final layer = layers[index];
              final isSelected = layer == selectedLayer;
              return Card(
                elevation: isSelected ? 8 : 2,
                color: isSelected ? Colors.purple.shade50 : null,
                child: InkWell(
                  onTap: () => onLayerSelected(layer),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        size: 32,
                        color: isSelected
                            ? Colors.purple.shade700
                            : Colors.grey[600],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        layer,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        Icon(Icons.check_circle, color: Colors.purple.shade700),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (selectedLayer != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: onPrev,
                  child: const Text('Précédent'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onNext,
                  child: const Text('Continuer'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Step 4: Éditer les POIs
class _StepEditPOIs extends StatefulWidget {
  final String? selectedLayer;
  final List<Map<String, dynamic>> pois;
  final Function(List<Map<String, dynamic>>) onPOIsChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _StepEditPOIs({
    required this.selectedLayer,
    required this.pois,
    required this.onPOIsChanged,
    required this.onNext,
    required this.onPrev,
  });

  @override
  State<_StepEditPOIs> createState() => _StepEditPOIsState();
}

class _StepEditPOIsState extends State<_StepEditPOIs> {
  late List<Map<String, dynamic>> _pois;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pois = List<Map<String, dynamic>>.from(widget.pois);
  }

  void _addPOI() {
    setState(() {
      _pois.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'name': 'Nouveau POI',
        'lat': 16.241,
        'lng': -61.534,
        'icon': 'pin',
        'color': '#FF0000',
      });
    });
    widget.onPOIsChanged(_pois);
  }

  void _removePOI(int index) {
    setState(() {
      _pois.removeAt(index);
    });
    widget.onPOIsChanged(_pois);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.teal.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Couche: ${widget.selectedLayer}\nAjoutez ou modifiez des POIs',
                  style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _pois.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun POI encore',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addPOI,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un POI'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pois.length,
                  itemBuilder: (context, index) {
                    final poi = _pois[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _hexToColor(
                            poi['color'] ?? '#FF0000',
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Text(poi['name'] ?? 'POI'),
                        subtitle: Text(
                          '${poi['lat']?.toStringAsFixed(3)}, ${poi['lng']?.toStringAsFixed(3)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removePOI(index),
                        ),
                        onTap: () => _editPOI(context, index),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _addPOI,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: widget.onPrev,
                child: const Text('Précédent'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onNext,
                child: const Text('Continuer'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editPOI(BuildContext context, int index) {
    final poi = _pois[index];
    _nameController.text = poi['name'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Éditer POI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du POI',
                hintText: 'Ex: Restaurant',
              ),
            ),
            const SizedBox(height: 12),
            Text('Latitude: ${poi['lat']?.toStringAsFixed(4)}'),
            Text('Longitude: ${poi['lng']?.toStringAsFixed(4)}'),
            const SizedBox(height: 12),
            Text('Couleur: ${poi['color']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _pois[index]['name'] = _nameController.text;
              });
              widget.onPOIsChanged(_pois);
              Navigator.pop(context);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
    } else if (hexString.length == 8 || hexString.length == 9) {
      buffer.write(hexString.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

// Step 5: Configurer l'apparence des POIs
class _StepStylePOIs extends StatefulWidget {
  final String? selectedLayer;
  final List<Map<String, dynamic>> pois;
  final Function(List<Map<String, dynamic>>) onStyleChanged;
  final VoidCallback onPrev;

  const _StepStylePOIs({
    required this.selectedLayer,
    required this.pois,
    required this.onStyleChanged,
    required this.onPrev,
  });

  @override
  State<_StepStylePOIs> createState() => _StepStylePOIsState();
}

class _StepStylePOIsState extends State<_StepStylePOIs> {
  late List<Map<String, dynamic>> _pois;
  int? _selectedPOIIndex;

  @override
  void initState() {
    super.initState();
    _pois = List<Map<String, dynamic>>.from(widget.pois);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade50, Colors.red.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.palette, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Configurez l\'apparence de chaque POI',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _pois.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.palette, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun POI à styler',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pois.length,
                  itemBuilder: (context, index) {
                    final poi = _pois[index];
                    final isSelected = _selectedPOIIndex == index;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 8 : 2,
                      color: isSelected ? Colors.orange.shade50 : null,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _hexToColor(
                            poi['color'] ?? '#FF0000',
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Text(poi['name'] ?? 'POI'),
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _selectedPOIIndex = expanded ? index : null;
                          });
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Couleur: '),
                                    GestureDetector(
                                      onTap: () => _pickColor(context, index),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _hexToColor(
                                            poi['color'] ?? '#FF0000',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text('Icône:'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: ['pin', 'star', 'heart', 'flag']
                                      .map(
                                        (icon) => ChoiceChip(
                                          label: Text(icon),
                                          selected: poi['icon'] == icon,
                                          onSelected: (selected) {
                                            setState(() {
                                              _pois[index]['icon'] = icon;
                                            });
                                            widget.onStyleChanged(_pois);
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 12),
                                const Text('Taille:'),
                                Slider(
                                  value: (poi['size'] ?? 24).toDouble(),
                                  min: 16,
                                  max: 40,
                                  divisions: 12,
                                  label: '${(poi['size'] ?? 24).toInt()} px',
                                  onChanged: (value) {
                                    setState(() {
                                      _pois[index]['size'] = value.toInt();
                                    });
                                    widget.onStyleChanged(_pois);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: widget.onPrev,
                child: const Text('Précédent'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ POIs publiés avec succès !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.publish),
                label: const Text('Publier'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _pickColor(BuildContext context, int index) {
    final colors = [
      '#FF0000',
      '#00FF00',
      '#0000FF',
      '#FFFF00',
      '#FF00FF',
      '#00FFFF',
      '#FFA500',
      '#800080',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une couleur'),
        content: Wrap(
          spacing: 8,
          children: colors
              .map(
                (color) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _pois[index]['color'] = color;
                    });
                    widget.onStyleChanged(_pois);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _hexToColor(color),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
    } else if (hexString.length == 8 || hexString.length == 9) {
      buffer.write(hexString.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
