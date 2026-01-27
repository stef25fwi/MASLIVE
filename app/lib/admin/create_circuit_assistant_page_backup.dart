/*
Backup local (NE PAS IMPORTER / NE PAS UTILISER).
Ce fichier est volontairement commenté pour éviter les erreurs d'analyse/compilation.

Pour restaurer une ancienne version, recopier le contenu dans un nouveau fichier de travail.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import '../ui/widgets/mapbox_web_view.dart';

/// Assistant step-by-step pour la création de circuit
const _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

class CreateCircuitAssistantPage extends StatefulWidget {
  const CreateCircuitAssistantPage({super.key});

  @override
  State<CreateCircuitAssistantPage> createState() =>
      _CreateCircuitAssistantPageState();
}

class _CreateCircuitAssistantPageState
    extends State<CreateCircuitAssistantPage> {
  int _step = 0;
  bool _isFocusMode = false;
  Timer? _autoSaveTimer;
          // Header avec instructions
          if (_isValidated && _selectedPreset != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.cyan.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Zone "${_presets.firstWhere((p) => p['id'] == _selectedPreset)['name']}" validée',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Sélecteur de mode (dessiner/prédéfini)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ToggleButtons(
              isSelected: [
                _selectedMode == 'draw',
                _selectedMode == 'preset',
              ],
              onPressed: (int index) {
                setState(() {
                  _selectedMode = index == 0 ? 'draw' : 'preset';
                });
              },
              borderRadius: BorderRadius.circular(8),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.draw),
                      SizedBox(width: 8),
                      Text('Dessiner'),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined),
                      SizedBox(width: 8),
                      Text('Zone prédéfinie'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _selectedMode == 'draw'
                ? _buildDrawMode()
                : _buildPresetMode(),
          ),

          // Footer avec stats et bouton validation
          if ((_selectedMode == 'draw' && _polygonPoints.isNotEmpty) ||
              (_selectedMode == 'preset' && _selectedPreset != null))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_selectedMode == 'draw') ...[
                    Icon(Icons.polyline, color: Colors.grey[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_polygonPoints.length} points',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (_selectedMode == 'preset' && _selectedPreset != null) ...[
                    Icon(Icons.location_on, color: Colors.grey[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _presets.firstWhere(
                        (p) => p['id'] == _selectedPreset,
                      )['name']!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isValidated ? widget.onNext : _validatePerimeter,
                    icon: Icon(_isValidated ? Icons.arrow_forward : Icons.check),
                    label: Text(_isValidated ? 'Continuer' : 'Valider périmètre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isValidated ? Colors.teal : Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Text(_getStepTitle(_step)),
        actions: [
          // Auto-save indicator
          if (_lastAutoSave != null && !_isFocusMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Tooltip(
                  message: 'Dernière sauvegarde: ${_formatTime(_lastAutoSave!)}',
                  child: Chip(
                    avatar: const Icon(Icons.cloud_done, size: 16, color: Colors.green),
                    label: Text(
                      'Auto-save',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          // Focus mode toggle
          IconButton(
            icon: Icon(_isFocusMode ? Icons.visibility : Icons.visibility_off),
            tooltip: _isFocusMode ? 'Désactiver mode focus' : 'Activer mode focus',
            onPressed: _toggleFocusMode,
          ),
          // Manual save
          if (!_isFocusMode)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Sauvegarder manuellement',
              onPressed: _showSaveDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildStepSelector(),
          Expanded(child: _buildStepContent()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Future<void> _showSaveDialog() async {
    final controller = TextEditingController(text: _mapName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nommer la carte'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nom de la carte',
              hintText: 'Ex: Circuit volcan vert',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Donnez un nom à la carte'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _mapName = result;
      });
      await _saveDraft(mapName: result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💾 Carte "$result" sauvegardée'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return '1/5 • Définir le périmètre';
      case 1:
        return '2/5 • Mode hors-ligne';
      case 2:
        return '3/5 • Tracer le circuit';
      case 3:
        return '4/5 • Verrouiller & segments';
      case 4:
        return '5/5 • Publier';
      default:
        return '';
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _StepPerimetre(onNext: _nextStep);
      case 1:
        return _StepTuile(onNext: _nextStep, onPrev: _prevStep);
      case 2:
        return _StepTracer(onNext: _nextStep, onPrev: _prevStep);
      case 3:
        return _StepVerrouSegment(onNext: _nextStep, onPrev: _prevStep);
      case 4:
        return _StepPublier(onPrev: _prevStep);
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
                    Text('Étape validée', style: Theme.of(context).textTheme.bodyMedium),
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
                  TextButton(onPressed: _prevStep, child: const Text('Précédent')),
                Row(
                  children: [
                    Text('Étape ${_step + 1}/5', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                    if (_step < 4)
                      ElevatedButton(onPressed: _nextStep, child: const Text('Suivant')),
                  ],
                ),
              ],
            ),
          ],
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

  void _goToStep(int step) {
    if (step < 0 || step > 4) return;
    setState(() {
      _step = step;
    });
  }

  Widget _buildStepSelector() {
    final steps = [
      'Périmètre',
      'Mode hors-ligne',
      'Tracer',
      'Segments',
      'Publier',
    ];

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
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${index + 1} • ${steps[index]}'),
                    if (isValidated) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    ],
                  ],
                ),
                selected: isActive,
                onSelected: (_) => _goToStep(index),
                selectedColor: Colors.blue.shade100,
              ),
            );
          }),
        ),
      ),
    );
  }
}

// --- Step 1: Définir le périmètre (10/10 Premium) ---
class _StepPerimetre extends StatefulWidget {
  final VoidCallback onNext;
  const _StepPerimetre({required this.onNext});

  @override
  State<_StepPerimetre> createState() => _StepPerimetreState();
}

class _StepPerimetreState extends State<_StepPerimetre> {
  final List<Map<String, double>> _polygonPoints = [];
  String _selectedMode = 'draw'; // 'draw' ou 'preset'
  String? _selectedPreset;
  bool _isValidated = false;

  final List<Map<String, String>> _presets = [
    {'name': 'Guadeloupe', 'id': 'gp'},
    {'name': 'Martinique', 'id': 'mq'},
    {'name': 'Pointe-à-Pitre', 'id': 'pap'},
    {'name': 'Fort-de-France', 'id': 'fdf'},
  ];

  void _addPoint(double lat, double lng) {
    if (_isValidated) return;
    setState(() {
      _polygonPoints.add({'lat': lat, 'lng': lng});
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isEmpty || _isValidated) return;
    setState(() {
      _polygonPoints.removeLast();
    });
  }

  void _clearPolygon() {
    if (_isValidated) return;
    setState(() {
      _polygonPoints.clear();
    });
  }

  void _validatePerimeter() {
    if (_selectedMode == 'draw' && _polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Au moins 3 points requis pour définir un périmètre',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedMode == 'preset' && _selectedPreset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Sélectionnez une zone prédéfinie'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _isValidated = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Périmètre validé et sauvegardé'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
          // Aperçu carte en direct (première)
          _MapPreviewWidget(
            title: 'Aperçu du périmètre',
            polygonPoints: _polygonPoints,
            selectedPreset: _selectedPreset,
            presetName: _selectedPreset != null
                ? _presets.firstWhere((p) => p['id'] == _selectedPreset)['name']
                : null,
          ),
          
          // Deuxième carte pour meilleure visibilité
          _MapPreviewWidget(
            title: 'Détail du périmètre',
            polygonPoints: _polygonPoints,
            selectedPreset: _selectedPreset,
            presetName: _selectedPreset != null
                ? _presets.firstWhere((p) => p['id'] == _selectedPreset)['name']
                : null,
          ),
          
          // Header avec instructions
          if (_isValidated && _selectedPreset != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.cyan.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Zone "${_presets.firstWhere((p) => p['id'] == _selectedPreset)['name']}" validée',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
              void ButtonSegment(
                value = 'draw',
                label = Text('Dessiner'),
                icon = Icon(Icons.draw),
              ),
              void ButtonSegment(
                value = 'preset',
                label = Text('Zone prédéfinie'),
                icon = Icon(Icons.map_outlined),
              ),
            ],
            selected: {_selectedMode},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _selectedMode = newSelection.first;
              });
            },
          ),
        ),

        // Content
        void Expanded(
          child = _selectedMode == 'draw'
              ? _buildDrawMode()
              : _buildPresetMode(),
        ),

        // Footer avec stats et bouton validation
        if ((_selectedMode, == 'draw' && _polygonPoints.isNotEmpty), ||
            (_selectedMode == 'preset' && _selectedPreset != null))
          Container(
            padding = const EdgeInsets.all(16),
            decoration = BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child = Row(
              children: [
                if (_selectedMode == 'draw') ...[
                  Icon(Icons.polyline, color: Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_polygonPoints.length} points',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (_selectedMode == 'preset' && _selectedPreset != null) ...[
                  Icon(Icons.location_on, color: Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _presets.firstWhere(
                      (p) => p['id'] == _selectedPreset,
                    )['name']!,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isValidated ? widget.onNext : _validatePerimeter,
                  icon: Icon(_isValidated ? Icons.arrow_forward : Icons.check),
                  label: Text(_isValidated ? 'Continuer' : 'Valider périmètre'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValidated ? Colors.teal : Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDrawMode() {
    return Stack(
      children: [
        // Zone carte : Mapbox si dispo, sinon placeholder
        Stack(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!),
              ),
              clipBehavior: Clip.hardEdge,
              child: kIsWeb && _mapboxToken.isNotEmpty
                  ? MapboxWebView(
                      accessToken: _mapboxToken,
                      initialLat: 16.242,
                      initialLng: -61.534,
                      initialZoom: 12.5,
                      styleUrl: 'mapbox://styles/mapbox/streets-v12',
                    )
                  : Center(
                      child: Text(
                        'Mapbox nécessite MAPBOX_ACCESS_TOKEN',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
            
            // Overlay pour capturer les clics (sauf si Mapbox est actif et détection native)
            if (!kIsWeb || _mapboxToken.isEmpty)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isValidated
                        ? null
                        : () {
                            _addPoint(
                              16.0 + _polygonPoints.length * 0.01,
                              -61.0 + _polygonPoints.length * 0.01,
                            );
                          },
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app, size: 48, color: Colors.white.withOpacity(0.8)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _isValidated
                                  ? 'Périmètre validé'
                                  : 'Clique sur la carte pour ajouter des points',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (_polygonPoints.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_polygonPoints.length} points placés',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          if (_isValidated) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Périmètre verrouillé',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              // Overlay instructions pour Mapbox (Web avec token)
              if (!_isValidated)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mapbox actif - Cliquez sur la carte pour ajouter des points (${_polygonPoints.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Périmètre validé (${_polygonPoints.length} points)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),

        // Floating action buttons (undo, clear)
        if (!_isValidated && _polygonPoints.isNotEmpty)
          Positioned(
            right: 24,
            top: 24,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'undo',
                  onPressed: _undoLastPoint,
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.undo),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'clear',
                  onPressed: _clearPolygon,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPresetMode() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Zones prédéfinies',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._presets.map((preset) {
          final isSelected = _selectedPreset == preset['id'];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: isSelected ? 4 : 1,
            color: isSelected ? Colors.blue.shade50 : null,
            child: ListTile(
              leading: Icon(
                Icons.location_city,
                color: isSelected ? Colors.blue : Colors.grey[600],
              ),
              title: Text(
                preset['name']!,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: Colors.blue.shade700)
                  : const Icon(Icons.chevron_right),
              onTap: _isValidated
                  ? null
                  : () {
                      setState(() {
                        _selectedPreset = preset['id'];
                      });
                    },
            ),
          );
        }),
        if (_isValidated && _selectedPreset != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Zone "${_presets.firstWhere((p) => p['id'] == _selectedPreset)['name']}" validée',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
  }
}

// --- Step 2: Configurer la carte & télécharger les tuiles (10/10 Premium) ---
class _StepTuile extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;
  const _StepTuile({required this.onNext, required this.onPrev});

  @override
  State<_StepTuile> createState() => _StepTuileState();
}

class _StepTuileState extends State<_StepTuile> {
  // Styles Mapbox disponibles
  final List<Map<String, dynamic>> _mapStyles = [
    {
      'id': 'streets-v12',
      'name': 'Streets',
      'url': 'mapbox://styles/mapbox/streets-v12',
      'icon': Icons.map,
      'description': 'Style standard avec routes et labels',
      'color': const Color(0xFF1A73E8),
    },
    {
      'id': 'outdoors-v12',
      'name': 'Outdoors',
      'url': 'mapbox://styles/mapbox/outdoors-v12',
      'icon': Icons.terrain,
      'description': 'Randonnée et activités extérieures',
      'color': const Color(0xFF34A853),
    },
    {
      'id': 'satellite-v9',
      'name': 'Satellite',
      'url': 'mapbox://styles/mapbox/satellite-v9',
      'icon': Icons.satellite_alt,
      'description': 'Imagerie satellite haute résolution',
      'color': const Color(0xFF5E35B1),
    },
    {
      'id': 'satellite-streets-v12',
      'name': 'Satellite Streets',
      'url': 'mapbox://styles/mapbox/satellite-streets-v12',
      'icon': Icons.layers,
      'description': 'Satellite avec routes et labels',
      'color': const Color(0xFF8E24AA),
    },
    {
      'id': 'light-v11',
      'name': 'Light',
      'url': 'mapbox://styles/mapbox/light-v11',
      'icon': Icons.wb_sunny,
      'description': 'Carte claire et minimaliste',
      'color': const Color(0xFFFFA726),
    },
    {
      'id': 'dark-v11',
      'name': 'Dark',
      'url': 'mapbox://styles/mapbox/dark-v11',
      'icon': Icons.dark_mode,
      'description': 'Carte sombre',
      'color': const Color(0xFF424242),
    },
  ];

  // Couches supplémentaires disponibles
  final List<Map<String, dynamic>> _layers = [
    {
      'id': 'traffic',
      'name': 'Trafic en temps réel',
      'icon': Icons.traffic,
      'description': 'Afficher les conditions de trafic',
      'color': const Color(0xFFFF5722),
    },
    {
      'id': 'terrain',
      'name': 'Relief 3D',
      'icon': Icons.landscape,
      'description': 'Afficher le relief en 3D',
      'color': const Color(0xFF795548),
    },
    {
      'id': 'buildings',
      'name': 'Bâtiments 3D',
      'icon': Icons.apartment,
      'description': 'Afficher les bâtiments en 3D',
      'color': const Color(0xFF607D8B),
    },
    {
      'id': 'hillshade',
      'name': 'Ombrage du relief',
      'icon': Icons.filter_b_and_w,
      'description': 'Ombres pour visualiser le relief',
      'color': const Color(0xFF9E9E9E),
    },
  ];

  String _selectedStyleId = 'outdoors-v12';
  final Set<String> _selectedLayers = {};
  double _zoomMin = 10;
  double _zoomMax = 16;
  String _quality = 'standard'; // 'low', 'standard', 'high'
  bool _isValidated = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _downloadPaused = false;

  // Configuration des textures de bâtiments 3D
  bool _buildingsTexturesEnabled = false;
  String _facadeTextureId = 'windows_modern';
  String _roofTextureId = 'concrete';
  double _facadeTextureScale = 1.0;
  double _roofTextureScale = 1.0;
  double _textureOpacity = 1.0;

  // Photos personnalisées
  bool _useCustomFacadePhoto = false;
  String? _customFacadePhotoUrl;
  String? _customFacadePhotoName;

  // Bâtiments spécifiques avec textures personnalisées
  final List<Map<String, dynamic>> _specificBuildings = [];
  bool _showSpecificBuildingsMode = false;

  // Textures prédéfinies pour façades
  final List<Map<String, dynamic>> _facadeTextures = [
    {
      'id': 'windows_modern',
      'name': 'Fenêtres modernes',
      'description': 'Façade moderne avec grandes fenêtres',
      'icon': Icons.window,
      'color': const Color(0xFF1976D2),
      'preview': '🏢',
    },
    {
      'id': 'windows_classic',
      'name': 'Fenêtres classiques',
      'description': 'Architecture traditionnelle',
      'icon': Icons.home,
      'color': const Color(0xFF5D4037),
      'preview': '🏛️',
    },
    {
      'id': 'brick_red',
      'name': 'Brique rouge',
      'description': 'Briques rouges traditionnelles',
      'icon': Icons.grid_4x4,
      'color': const Color(0xFFD32F2F),
      'preview': '🧱',
    },
    {
      'id': 'brick_brown',
      'name': 'Brique marron',
      'description': 'Briques brunes rustiques',
      'icon': Icons.grid_4x4,
      'color': const Color(0xFF6D4C41),
      'preview': '🟫',
    },
    {
      'id': 'concrete',
      'name': 'Béton',
      'description': 'Béton brut industriel',
      'icon': Icons.square,
      'color': const Color(0xFF757575),
      'preview': '⬜',
    },
    {
      'id': 'glass_blue',
      'name': 'Verre bleuté',
      'description': 'Façade vitrée réfléchissante',
      'icon': Icons.layers,
      'color': const Color(0xFF0288D1),
      'preview': '💎',
    },
    {
      'id': 'wood_panels',
      'name': 'Panneaux bois',
      'description': 'Bardage en bois naturel',
      'icon': Icons.deck,
      'color': const Color(0xFF8D6E63),
      'preview': '🪵',
    },
    {
      'id': 'metal',
      'name': 'Métal',
      'description': 'Panneaux métalliques',
      'icon': Icons.construction,
      'color': const Color(0xFF546E7A),
      'preview': '🔩',
    },
  ];

  // Textures prédéfinies pour toits
  final List<Map<String, dynamic>> _roofTextures = [
    {
      'id': 'concrete',
      'name': 'Béton',
      'description': 'Toit-terrasse en béton',
      'icon': Icons.square,
      'color': const Color(0xFF757575),
      'preview': '⬜',
    },
    {
      'id': 'tiles_red',
      'name': 'Tuiles rouges',
      'description': 'Tuiles méditerranéennes',
      'icon': Icons.roofing,
      'color': const Color(0xFFD84315),
      'preview': '🔴',
    },
    {
      'id': 'tiles_brown',
      'name': 'Tuiles brunes',
      'description': 'Tuiles traditionnelles',
      'icon': Icons.roofing,
      'color': const Color(0xFF5D4037),
      'preview': '🟤',
    },
    {
      'id': 'slate',
      'name': 'Ardoise',
      'description': 'Ardoise grise classique',
      'icon': Icons.layers,
      'color': const Color(0xFF455A64),
      'preview': '⬛',
    },
    {
      'id': 'metal_gray',
      'name': 'Métal gris',
      'description': 'Tôle métallique',
      'icon': Icons.construction,
      'color': const Color(0xFF607D8B),
      'preview': '🔧',
    },
    {
      'id': 'green_roof',
      'name': 'Toit végétalisé',
      'description': 'Toiture verte écologique',
      'icon': Icons.grass,
      'color': const Color(0xFF388E3C),
      'preview': '🌿',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Aperçu carte en direct
        _MapPreviewWidget(
          title: 'Aperçu de la configuration',
          selectedStyle: _selectedStyleId,
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, color: Colors.blue.shade700, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configuration de la carte',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                      Text(
                        'Choisissez le style et les couches pour votre circuit',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Style de carte
          Text(
            'Style de carte Mapbox',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez le style de base pour votre carte',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Grille de styles
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _mapStyles.length,
            itemBuilder: (context, index) {
              final style = _mapStyles[index];
              final isSelected = _selectedStyleId == style['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedStyleId = style['id'];
                    _isValidated = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? style['color'].withValues(alpha: 0.1)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected ? style['color'] : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        style['icon'],
                        size: 40,
                        color: isSelected
                            ? style['color']
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        style['name'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? style['color']
                              : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          style['description'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Icon(
                          Icons.check_circle,
                          color: style['color'],
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Section: Couches supplémentaires
          Text(
            'Couches supplémentaires',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activez des couches additionnelles (optionnel)',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Liste des couches
          ..._layers.map((layer) {
            final isSelected = _selectedLayers.contains(layer['id']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? layer['color'].withValues(alpha: 0.1)
                      : Colors.grey.shade50,
                  border: Border.all(
                    color: isSelected ? layer['color'] : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedLayers.add(layer['id']);
                      } else {
                        _selectedLayers.remove(layer['id']);
                      }
                      _isValidated = false;
                    });
                  },
                  title: Row(
                    children: [
                      Icon(layer['icon'], color: layer['color'], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          layer['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(left: 36, top: 4),
                    child: Text(
                      layer['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  activeColor: layer['color'],
                ),
              ),
            );
          }),

          const SizedBox(height: 32),

          // Section: Textures de bâtiments 3D (Premium Advanced)
          if (_selectedLayers.contains('buildings'))
            _buildBuildingTexturesSection(),

          if (_selectedLayers.contains('buildings')) const SizedBox(height: 32),

          // Section: Niveaux de zoom
          Text(
            'Niveaux de zoom',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Définissez les niveaux de zoom min/max pour les tuiles hors-ligne',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Zoom minimum',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Text(
                      '${_zoomMin.toInt()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _zoomMin,
                  min: 8,
                  max: 15,
                  divisions: 7,
                  label: _zoomMin.toInt().toString(),
                  onChanged: (value) {
                    setState(() {
                      _zoomMin = value;
                      if (_zoomMax < _zoomMin) _zoomMax = _zoomMin;
                      _isValidated = false;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Zoom maximum',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Text(
                      '${_zoomMax.toInt()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _zoomMax,
                  min: 8,
                  max: 18,
                  divisions: 10,
                  label: _zoomMax.toInt().toString(),
                  onChanged: (value) {
                    setState(() {
                      _zoomMax = value;
                      if (_zoomMin > _zoomMax) _zoomMin = _zoomMax;
                      _isValidated = false;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Section: Qualité des tuiles
          Text(
            'Qualité des tuiles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'low',
                label: Text('Économique'),
                icon: Icon(Icons.data_saver_on),
              ),
              ButtonSegment(
                value: 'standard',
                label: Text('Standard'),
                icon: Icon(Icons.check),
              ),
              ButtonSegment(
                value: 'high',
                label: Text('Haute'),
                icon: Icon(Icons.hd),
              ),
            ],
            selected: {_quality},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _quality = newSelection.first;
                _isValidated = false;
              });
            },
          ),

          const SizedBox(height: 16),

          // Info qualité
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getQualityInfo(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Estimation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade50, Colors.purple.shade100],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.purple.shade700, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Estimation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildEstimationRow(
                  'Style',
                  _mapStyles.firstWhere(
                    (s) => s['id'] == _selectedStyleId,
                  )['name'],
                ),
                if (_selectedLayers.isNotEmpty)
                  _buildEstimationRow(
                    'Couches',
                    '${_selectedLayers.length} activée(s)',
                  ),
                _buildEstimationRow(
                  'Zoom',
                  '${_zoomMin.toInt()} - ${_zoomMax.toInt()}',
                ),
                _buildEstimationRow('Qualité', _getQualityLabel()),
                const Divider(height: 24),
                _buildEstimationRow(
                  'Taille estimée',
                  _calculateEstimatedSize(),
                  isHighlight: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Boutons d'action
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_isValidated)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isValidated = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 12),
                            Text(
                              'Configuration validée : ${_mapStyles.firstWhere((s) => s['id'] == _selectedStyleId)['name']}',
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Valider la configuration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              if (_isValidated) ...[
                if (!_isDownloading)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _isValidated = false);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (!_isDownloading) const SizedBox(width: 12),
                if (!_isDownloading)
                  ElevatedButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.download),
                    label: const Text('Télécharger maintenant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                if (!_isDownloading) const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: widget.onNext,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_isDownloading && _downloadProgress >= 1.0 ? 'Étape suivante' : 'Passer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (_isValidated && !_isDownloading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Configuration validée et prête pour le téléchargement',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Barre de progression du téléchargement
          if (_isDownloading) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _downloadProgress >= 1.0
                              ? Icons.check_circle
                              : Icons.downloading,
                          color: _downloadProgress >= 1.0
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _downloadProgress >= 1.0
                                    ? 'Téléchargement terminé !'
                                    : _downloadPaused
                                        ? 'Téléchargement en pause'
                                        : 'Téléchargement en cours',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _downloadProgress >= 1.0
                                      ? Colors.green.shade900
                                      : Colors.grey.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_downloadProgress * 100).toInt()}% - ${_calculateDownloadedSize()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _downloadProgress >= 1.0
                              ? Colors.green.shade600
                              : Colors.blue.shade600,
                        ),
                      ),
                    ),
                    if (_downloadProgress < 1.0) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _downloadPaused = !_downloadPaused;
                              });
                              if (!_downloadPaused) _continueDownload();
                            },
                            icon: Icon(
                              _downloadPaused ? Icons.play_arrow : Icons.pause,
                              size: 20,
                            ),
                            label: Text(_downloadPaused ? 'Reprendre' : 'Pause'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isDownloading = false;
                                _downloadProgress = 0.0;
                                _downloadPaused = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Téléchargement annulé'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                            icon: const Icon(Icons.close, size: 20),
                            label: const Text('Annuler'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_downloadProgress >= 1.0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.offline_pin,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Les tuiles sont maintenant disponibles hors ligne',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    ),
  ],
    );
  }

  // Section premium pour les textures de bâtiments 3D
  Widget _buildBuildingTexturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Textures de bâtiments 3D',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade600, Colors.deepPurple.shade600],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'PREMIUM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Appliquez des textures réalistes sur les façades et toits',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        // Mode de configuration: Global vs Spécifique
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade300, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.architecture,
                    color: Colors.deepPurple.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mode de configuration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Tous les bâtiments'),
                    icon: Icon(Icons.domain),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Bâtiments spécifiques'),
                    icon: Icon(Icons.location_city),
                  ),
                ],
                selected: {_showSpecificBuildingsMode},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _showSpecificBuildingsMode = newSelection.first;
                    _isValidated = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.deepPurple.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _showSpecificBuildingsMode
                            ? 'Sélectionnez des bâtiments individuels sur la carte'
                            : 'La texture sera appliquée à tous les bâtiments',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Activation des textures
        Container(
          decoration: BoxDecoration(
            color: _buildingsTexturesEnabled
                ? Colors.purple.shade50
                : Colors.grey.shade100,
            border: Border.all(
              color: _buildingsTexturesEnabled
                  ? Colors.purple.shade300
                  : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            value: _buildingsTexturesEnabled,
            onChanged: (value) {
              setState(() {
                _buildingsTexturesEnabled = value;
                _isValidated = false;
              });
            },
            title: Row(
              children: [
                Icon(
                  Icons.texture,
                  color: _buildingsTexturesEnabled
                      ? Colors.purple.shade700
                      : Colors.grey.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Activer les textures personnalisées',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(left: 36, top: 4),
              child: Text(
                _buildingsTexturesEnabled
                    ? 'Textures activées - configurez ci-dessous'
                    : 'Les bâtiments utiliseront le rendu par défaut',
                style: TextStyle(fontSize: 12),
              ),
            ),
            activeThumbColor: Colors.purple.shade600,
          ),
        ),

        if (_buildingsTexturesEnabled) ...[
          const SizedBox(height: 24),

          // Si mode bâtiments spécifiques, afficher la gestion des bâtiments
          if (_showSpecificBuildingsMode)
            _buildSpecificBuildingsSection()
          else
            // Sinon, configuration globale comme avant
            _buildGlobalTextureConfiguration(),
        ],
      ],
    );
  }

  // Configuration globale pour tous les bâtiments
  Widget _buildGlobalTextureConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Textures de façades
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade50, Colors.indigo.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business, color: Colors.indigo.shade700, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Texture des façades',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Choix entre texture prédéfinie et photo personnalisée
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Textures'),
                    icon: Icon(Icons.texture),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Photo perso'),
                    icon: Icon(Icons.photo_library),
                  ),
                ],
                selected: {_useCustomFacadePhoto},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _useCustomFacadePhoto = newSelection.first;
                    _isValidated = false;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Grille de sélection de textures façades ou upload photo
              if (!_useCustomFacadePhoto)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _facadeTextures.length,
                  itemBuilder: (context, index) {
                    final texture = _facadeTextures[index];
                    final isSelected = _facadeTextureId == texture['id'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _facadeTextureId = texture['id'];
                          _isValidated = false;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.indigo.shade50,
                          border: Border.all(
                            color: isSelected
                                ? texture['color']
                                : Colors.indigo.shade200,
                            width: isSelected ? 3 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              texture['preview'],
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              texture['icon'],
                              size: 20,
                              color: isSelected
                                  ? texture['color']
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                texture['name'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? texture['color']
                                      : Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              else
                // Section photo personnalisée
                _buildCustomPhotoSection(),

              const SizedBox(height: 16),

              // Échelle de la texture façade (seulement si pas de photo perso ou si photo chargée)
              if (!_useCustomFacadePhoto || _customFacadePhotoUrl != null)
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.straighten,
                          color: Colors.indigo.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Échelle: ${_facadeTextureScale.toStringAsFixed(1)}x',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _facadeTextureScale,
                      min: 0.5,
                      max: 3.0,
                      divisions: 25,
                      label: '${_facadeTextureScale.toStringAsFixed(1)}x',
                      activeColor: Colors.indigo.shade600,
                      onChanged: (value) {
                        setState(() {
                          _facadeTextureScale = value;
                          _isValidated = false;
                        });
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Textures de toits
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade50, Colors.orange.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.roofing, color: Colors.orange.shade700, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Texture des toits',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grille de sélection de textures toits
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _roofTextures.length,
                itemBuilder: (context, index) {
                  final texture = _roofTextures[index];
                  final isSelected = _roofTextureId == texture['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _roofTextureId = texture['id'];
                        _isValidated = false;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.orange.shade50,
                        border: Border.all(
                          color: isSelected
                              ? texture['color']
                              : Colors.orange.shade200,
                          width: isSelected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            texture['preview'],
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            texture['icon'],
                            size: 20,
                            color: isSelected
                                ? texture['color']
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              texture['name'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? texture['color']
                                    : Colors.grey.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Échelle de la texture toit
              Row(
                children: [
                  Icon(
                    Icons.straighten,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Échelle: ${_roofTextureScale.toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _roofTextureScale,
                min: 0.5,
                max: 3.0,
                divisions: 25,
                label: '${_roofTextureScale.toStringAsFixed(1)}x',
                activeColor: Colors.orange.shade600,
                onChanged: (value) {
                  setState(() {
                    _roofTextureScale = value;
                    _isValidated = false;
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Paramètres avancés
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: Colors.deepPurple.shade700, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Paramètres avancés',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Opacité des textures
              Row(
                children: [
                  Icon(
                    Icons.opacity,
                    color: Colors.deepPurple.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Opacité: ${(_textureOpacity * 100).toInt()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple.shade800,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _textureOpacity,
                min: 0.3,
                max: 1.0,
                divisions: 14,
                label: '${(_textureOpacity * 100).toInt()}%',
                activeColor: Colors.deepPurple.shade600,
                onChanged: (value) {
                  setState(() {
                    _textureOpacity = value;
                    _isValidated = false;
                  });
                },
              ),

              const SizedBox(height: 8),

              // Info technique
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.deepPurple.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Les textures seront appliquées via fill-extrusion-pattern dans Mapbox GL JS',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.deepPurple.shade900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Aperçu de la configuration
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade50, Colors.teal.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade300, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.preview, color: Colors.teal.shade700, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Configuration actuelle',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextureConfigRow(
                'Façades',
                _facadeTextures.firstWhere(
                  (t) => t['id'] == _facadeTextureId,
                )['name'],
                '${_facadeTextures.firstWhere((t) => t['id'] == _facadeTextureId)['preview']} ${_facadeTextureScale.toStringAsFixed(1)}x',
              ),
              const SizedBox(height: 8),
              _buildTextureConfigRow(
                'Toits',
                _roofTextures.firstWhere(
                  (t) => t['id'] == _roofTextureId,
                )['name'],
                '${_roofTextures.firstWhere((t) => t['id'] == _roofTextureId)['preview']} ${_roofTextureScale.toStringAsFixed(1)}x',
              ),
              const SizedBox(height: 8),
              _buildTextureConfigRow(
                'Opacité',
                '${(_textureOpacity * 100).toInt()}%',
                _textureOpacity > 0.7 ? '✓ Visible' : '⚠️ Transparent',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Section pour gérer les bâtiments spécifiques
  Widget _buildSpecificBuildingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec action
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan.shade50, Colors.cyan.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.shade300, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.apartment, color: Colors.cyan.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bâtiments personnalisés',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyan.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_specificBuildings.length} bâtiment(s) configuré(s)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.cyan.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addSpecificBuilding(),
                    icon: const Icon(Icons.add_location_alt, size: 18),
                    label: const Text('Ajouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.cyan.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cliquez sur "Ajouter" puis sélectionnez un bâtiment sur la carte',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.cyan.shade900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Liste des bâtiments configurés
        if (_specificBuildings.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.location_city_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun bâtiment spécifique',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ajoutez des bâtiments pour leur appliquer\ndes textures personnalisées',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_specificBuildings.asMap().entries.map((entry) {
            final index = entry.key;
            final building = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBuildingCard(building, index),
            );
          })),
      ],
    );
  }

  // Card pour un bâtiment spécifique
  Widget _buildBuildingCard(Map<String, dynamic> building, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du bâtiment
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade50, Colors.indigo.shade100],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building['name'] ?? 'Bâtiment ${index + 1}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.indigo.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Lat: ${building['lat']?.toStringAsFixed(4) ?? 'N/A'}, '
                            'Lng: ${building['lng']?.toStringAsFixed(4) ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.indigo.shade700),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: const [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ],
                      ),
                      onTap: () => _editBuildingTexture(index),
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: const [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _specificBuildings.removeAt(index);
                          _isValidated = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bâtiment supprimé'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenu - Texture appliquée
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo de façade si présente
                if (building['facadePhotoUrl'] != null) ...[
                  Text(
                    'Photo de façade',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        building['facadePhotoUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.red.shade400,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Infos de configuration
                _buildBuildingInfoRow(
                  Icons.texture,
                  'Façade',
                  building['facadeTexture'] ?? 'Aucune',
                  Colors.indigo,
                ),
                const SizedBox(height: 8),
                _buildBuildingInfoRow(
                  Icons.roofing,
                  'Toit',
                  building['roofTexture'] ?? 'Par défaut',
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildBuildingInfoRow(
                  Icons.straighten,
                  'Échelle',
                  '${building['scale']?.toStringAsFixed(1) ?? '1.0'}x',
                  Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingInfoRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color.lerp(color, Colors.black, 0.3)!,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color.lerp(color, Colors.black, 0.7)!,
            ),
          ),
        ],
      ),
    );
  }

  // Ajouter un bâtiment spécifique
  void _addSpecificBuilding() {
    showDialog(
      context: context,
      builder: (context) => _BuildingConfigDialog(
        onSave: (buildingData) {
          setState(() {
            _specificBuildings.add(buildingData);
            _isValidated = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Bâtiment ajouté avec succès'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  // Modifier la texture d'un bâtiment
  void _editBuildingTexture(int index) {
    final building = _specificBuildings[index];
    showDialog(
      context: context,
      builder: (context) => _BuildingConfigDialog(
        initialData: building,
        onSave: (buildingData) {
          setState(() {
            _specificBuildings[index] = buildingData;
            _isValidated = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Bâtiment modifié'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextureConfigRow(String label, String value, String extra) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.teal.shade900),
            ),
          ),
          Text(
            extra,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Section pour uploader une photo personnalisée
  Widget _buildCustomPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade300, width: 2),
      ),
      child: Column(
        children: [
          if (_customFacadePhotoUrl == null) ...[
            // État initial - pas de photo
            Icon(
              Icons.add_photo_alternate,
              size: 64,
              color: Colors.indigo.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune photo sélectionnée',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Importez une photo pour l\'appliquer sur les façades',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            // Boutons d'import
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickPhotoFromGallery(),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showUrlInputDialog(),
                  icon: const Icon(Icons.link),
                  label: const Text('URL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info technique
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Formats acceptés: JPG, PNG, WEBP. Idéal: 512x512px ou plus',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Photo chargée - aperçu
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _customFacadePhotoUrl!.startsWith('http')
                    ? Image.network(
                        _customFacadePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade400,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Erreur de chargement',
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              color: Colors.indigo.shade400,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _customFacadePhotoName ?? 'Image locale',
                              style: TextStyle(color: Colors.indigo.shade700),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Infos photo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _customFacadePhotoName ?? 'Photo personnalisée',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_customFacadePhotoUrl != null &&
                            _customFacadePhotoUrl!.startsWith('http'))
                          Text(
                            _customFacadePhotoUrl!.length > 50
                                ? '${_customFacadePhotoUrl!.substring(0, 50)}...'
                                : _customFacadePhotoUrl!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhotoFromGallery(),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Changer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo.shade700,
                    side: BorderSide(color: Colors.indigo.shade300),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _customFacadePhotoUrl = null;
                      _customFacadePhotoName = null;
                      _isValidated = false;
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Simuler la sélection d'une photo depuis la galerie
  void _pickPhotoFromGallery() {
    // En production, utiliser image_picker package
    // Pour l'instant, simulation avec une URL de démo
    setState(() {
      _customFacadePhotoUrl =
          'https://picsum.photos/512/512?random=${DateTime.now().millisecondsSinceEpoch}';
      _customFacadePhotoName =
          'facade_${DateTime.now().millisecondsSinceEpoch}.jpg';
      _isValidated = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Photo importée avec succès'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Dialog pour entrer une URL d'image
  void _showUrlInputDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link, color: Colors.indigo),
            SizedBox(width: 12),
            Text('Importer depuis une URL'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Collez l\'URL de votre image de façade :',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'URL de l\'image',
                hintText: 'https://example.com/facade.jpg',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exemple: images depuis Firebase Storage, Imgur, etc.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty &&
                  (url.startsWith('http://') || url.startsWith('https://'))) {
                setState(() {
                  _customFacadePhotoUrl = url;
                  _customFacadePhotoName = url.split('/').last.split('?').first;
                  _isValidated = false;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text('URL ajoutée avec succès'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'URL invalide. Doit commencer par http:// ou https://',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Importer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimationRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 14 : 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: Colors.purple.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade900,
            ),
          ),
        ],
      ),
    );
  }

  String _getQualityLabel() {
    switch (_quality) {
      case 'low':
        return 'Économique';
      case 'standard':
        return 'Standard';
      case 'high':
        return 'Haute';
      default:
        return 'Standard';
    }
  }

  String _getQualityInfo() {
    switch (_quality) {
      case 'low':
        return 'Économique : Fichiers plus légers, idéal pour une connexion limitée (qualité réduite)';
      case 'standard':
        return 'Standard : Bon équilibre entre qualité et taille de fichier';
      case 'high':
        return 'Haute : Meilleure qualité, fichiers plus volumineux (recommandé pour Wi-Fi)';
      default:
        return '';
    }
  }

  String _calculateEstimatedSize() {
    // Calcul approximatif basé sur le zoom et la qualité
    final zoomRange = _zoomMax - _zoomMin + 1;
    double baseSize = 50.0; // Mo de base

    // Facteur zoom (exponentiel)
    final zoomFactor = zoomRange * 2.5;

    // Facteur qualité
    double qualityFactor = 1.0;
    switch (_quality) {
      case 'low':
        qualityFactor = 0.6;
        break;
      case 'standard':
        qualityFactor = 1.0;
        break;
      case 'high':
        qualityFactor = 1.8;
        break;
    }

    // Facteur couches (chaque couche ajoute ~30%)
    final layerFactor = 1.0 + (_selectedLayers.length * 0.3);

    final estimatedSize = baseSize * zoomFactor * qualityFactor * layerFactor;

    if (estimatedSize < 100) {
      return '~${estimatedSize.toStringAsFixed(0)} Mo';
    } else if (estimatedSize < 1024) {
      return '~${estimatedSize.toStringAsFixed(0)} Mo';
    } else {
      return '~${(estimatedSize / 1024).toStringAsFixed(1)} Go';
    }
  }
  
  String _calculateDownloadedSize() {
    final total = _calculateEstimatedSize();
    final match = RegExp(r'~([\d.]+)\s*(Mo|Go)').firstMatch(total);
    if (match != null) {
      final size = double.parse(match.group(1)!);
      final unit = match.group(2);
      final downloaded = size * _downloadProgress;
      return '${downloaded.toStringAsFixed(1)} $unit / $total';
    }
    return total;
  }
  
  void _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadPaused = false;
    });
    _continueDownload();
  }
  
  void _continueDownload() async {
    // Simulation de téléchargement
    while (_downloadProgress < 1.0 && !_downloadPaused && _isDownloading) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted && _isDownloading && !_downloadPaused) {
        setState(() {
          _downloadProgress += 0.02;
          if (_downloadProgress > 1.0) _downloadProgress = 1.0;
        });
      }
    }
    
    if (_downloadProgress >= 1.0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Tuiles téléchargées avec succès !'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

// --- Step 3: Tracer le circuit (10/10 Premium) ---
class _StepTracer extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;
  const _StepTracer({required this.onNext, required this.onPrev});

  @override
  State<_StepTracer> createState() => _StepTracerState();
}

class _StepTracerState extends State<_StepTracer> {
  // Points du tracé
  final List<Map<String, dynamic>> _tracePoints = [];

  // Configuration
  String _traceMode = 'manual'; // 'manual', 'follow_roads', 'straight'
  bool _showElevation = false;
  bool _snapToRoads = true;
  double _simplificationTolerance = 0.0001;
  bool _movePointMode = false; // Mode déplacement de point
  int? _selectedPointIndex; // Index du point sélectionné pour déplacement

  // État
  bool _isValidated = false;

  // Statistiques
  double _totalDistance = 0.0;
  double _elevationGain = 0.0;
  double _elevationLoss = 0.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Aperçu carte en direct
        _MapPreviewWidget(
          title: 'Aperçu du tracé',
          routePoints: _tracePoints.map((p) => {
            'lat': p['lat'] as double,
            'lng': p['lng'] as double,
          }).toList(),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.route, color: Colors.green.shade700, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tracer le circuit',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                        'Dessinez l\'itinéraire sur la carte',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Mode de tracé avec long-press hint
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mode de tracé',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Tooltip(
                message: 'Long-press sur un mode pour voir les détails',
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          GestureDetector(
            onLongPress: () {
              _showTraceModeHelp(context);
            },
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'manual',
                  label: Text('Manuel'),
                  icon: Icon(Icons.gesture),
                ),
                ButtonSegment(
                  value: 'follow_roads',
                  label: Text('Suivre routes'),
                  icon: Icon(Icons.alt_route),
                ),
                ButtonSegment(
                  value: 'straight',
                  label: Text('Ligne droite'),
                  icon: Icon(Icons.straight),
                ),
              ],
              selected: {_traceMode},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _traceMode = newSelection.first;
                  _isValidated = false;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // Info sur le mode
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getTraceModeDescription(),
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Carte interactive (placeholder)
          Container(
            height: 400,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400, width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Carte interactive Mapbox',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _movePointMode && _selectedPointIndex != null
                            ? 'Cliquez pour déplacer le point sélectionné'
                            : 'Cliquez pour ajouter des points',
                        style: TextStyle(
                          fontSize: 14,
                          color: _movePointMode && _selectedPointIndex != null
                              ? Colors.blue.shade700
                              : Colors.grey.shade500,
                          fontWeight: _movePointMode && _selectedPointIndex != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                // Boutons flottants sur la carte
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      _buildMapButton(
                        icon: Icons.my_location,
                        tooltip: 'Centrer sur ma position',
                        onPressed: () => _centerOnLocation(),
                      ),
                      const SizedBox(height: 8),
                      _buildMapButton(
                        icon: Icons.zoom_in,
                        tooltip: 'Zoom +',
                        onPressed: () {},
                      ),
                      const SizedBox(height: 8),
                      _buildMapButton(
                        icon: Icons.zoom_out,
                        tooltip: 'Zoom -',
                        onPressed: () {},
                      ),
                      const SizedBox(height: 8),
                      _buildMapButton(
                        icon: Icons.layers,
                        tooltip: 'Changer de fond',
                        onPressed: () {},
                      ),
                      const SizedBox(height: 8),
                      _buildMapButton(
                        icon: _movePointMode ? Icons.pan_tool : Icons.open_with,
                        tooltip: _movePointMode ? 'Désactiver déplacement' : 'Déplacer un point',
                        onPressed: () {
                          setState(() {
                            _movePointMode = !_movePointMode;
                            _selectedPointIndex = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _movePointMode
                                    ? 'Mode déplacement activé - Sélectionnez un point'
                                    : 'Mode déplacement désactivé',
                              ),
                              backgroundColor: _movePointMode ? Colors.blue : Colors.grey,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Boutons d'action en bas
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _tracePoints.isEmpty
                            ? null
                            : () => _undoLastPoint(),
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('Annuler'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _tracePoints.isEmpty
                            ? null
                            : () => _clearTrace(),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Effacer tout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _addDemoPoint(),
                        icon: Icon(
                          _movePointMode && _selectedPointIndex != null
                              ? Icons.open_with
                              : Icons.add_location,
                          size: 18,
                        ),
                        label: Text(
                          _movePointMode && _selectedPointIndex != null
                              ? 'Déplacer ici'
                              : 'Ajouter point',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _movePointMode && _selectedPointIndex != null
                              ? Colors.blue
                              : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Mini-map preview
          if (_tracePoints.isNotEmpty)
            _MiniMapPreview(
              routePoints: _tracePoints.map((p) => {
                'lat': p['lat'] as double? ?? 0.0,
                'lng': p['lng'] as double? ?? 0.0,
              }).toList(),
              onPointTap: (index) {
                setState(() {
                  _selectedPointIndex = index;
                  _movePointMode = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📍 Point ${index + 1} sélectionné - Cliquez sur "Déplacer ici" pour le repositionner'),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
            ),

          if (_tracePoints.isNotEmpty)
            const SizedBox(height: 16),

          // Statistiques du tracé
          if (_tracePoints.isNotEmpty) ...[
            Text(
              'Statistiques du tracé',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade50, Colors.purple.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          Icons.straighten,
                          'Distance',
                          '${_totalDistance.toStringAsFixed(2)} km',
                          Colors.purple,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          Icons.place,
                          'Points',
                          '${_tracePoints.length}',
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          Icons.trending_up,
                          'Dénivelé +',
                          '${_elevationGain.toStringAsFixed(0)} m',
                          Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          Icons.trending_down,
                          'Dénivelé -',
                          '${_elevationLoss.toStringAsFixed(0)} m',
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],

          // Options avancées
          Text(
            'Options avancées',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            value: _snapToRoads,
            onChanged: (value) {
              setState(() {
                _snapToRoads = value;
                _isValidated = false;
              });
            },
            title: const Text('Aimanter aux routes'),
            subtitle: const Text(
              'Les points s\'alignent automatiquement sur les routes',
            ),
            activeThumbColor: Colors.green,
          ),

          const SizedBox(height: 8),

          SwitchListTile(
            value: _showElevation,
            onChanged: (value) {
              setState(() {
                _showElevation = value;
              });
            },
            title: const Text('Afficher le profil d\'élévation'),
            subtitle: const Text('Visualiser les montées et descentes'),
            activeThumbColor: Colors.green,
          ),

          if (_showElevation) ...[
            const SizedBox(height: 16),
            Container(
              height: 150,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Profil d\'élévation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Graphique des altitudes le long du parcours',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Simplification du tracé
          Text(
            'Simplification du tracé',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Réduire le nombre de points tout en conservant la forme (algorithme Douglas-Peucker)',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Icon(Icons.tune, color: Colors.indigo.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tolérance: ${(_simplificationTolerance * 10000).toStringAsFixed(1)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade800,
                ),
              ),
              const Spacer(),
              Text(
                _simplificationTolerance == 0 ? 'Désactivée' : 'Active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _simplificationTolerance == 0
                      ? Colors.grey
                      : Colors.green,
                ),
              ),
            ],
          ),
          Slider(
            value: _simplificationTolerance,
            min: 0,
            max: 0.001,
            divisions: 20,
            label: _simplificationTolerance == 0
                ? 'OFF'
                : (_simplificationTolerance * 10000).toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _simplificationTolerance = value;
                _isValidated = false;
              });
            },
          ),

          const SizedBox(height: 24),

          // Liste des points
          if (_tracePoints.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Points du tracé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _exportTraceToJson(),
                  icon: const Icon(Icons.code, size: 18),
                  label: const Text('Exporter JSON'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _tracePoints.length,
                itemBuilder: (context, index) {
                  final point = _tracePoints[index];
                  final isStart = index == 0;
                  final isEnd = index == _tracePoints.length - 1;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isStart
                            ? Colors.green
                            : isEnd
                            ? Colors.red
                            : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          isStart
                              ? 'D'
                              : isEnd
                              ? 'A'
                              : '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      'Lat: ${point['lat'].toStringAsFixed(5)}, Lng: ${point['lng'].toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      isStart
                          ? 'Départ'
                          : isEnd
                          ? 'Arrivée'
                          : 'Point intermédiaire',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_movePointMode)
                          IconButton(
                            icon: Icon(
                              _selectedPointIndex == index
                                  ? Icons.check_circle
                                  : Icons.open_with,
                              color: _selectedPointIndex == index
                                  ? Colors.blue
                                  : Colors.grey,
                              size: 20,
                            ),
                            tooltip: _selectedPointIndex == index
                                ? 'Point sélectionné'
                                : 'Déplacer ce point',
                            onPressed: () {
                              if (_selectedPointIndex == index) {
                                // Désélectionner
                                setState(() => _selectedPointIndex = null);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Point désélectionné'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              } else {
                                // Sélectionner pour déplacement
                                setState(() => _selectedPointIndex = index);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Point ${isStart ? 'Départ' : isEnd ? 'Arrivée' : index + 1} sélectionné - Cliquez sur la carte pour le déplacer',
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              }
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () {
                            setState(() {
                              _tracePoints.removeAt(index);
                              if (_selectedPointIndex == index) {
                                _selectedPointIndex = null;
                              }
                              _recalculateStats();
                              _isValidated = false;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
          ],

          // Validation
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_isValidated && _tracePoints.length >= 2)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isValidated = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 12),
                            Text(
                              'Tracé validé : ${_tracePoints.length} points, ${_totalDistance.toStringAsFixed(2)} km',
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Valider le tracé'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              if (_isValidated) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isValidated = false);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: widget.onNext,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Étape suivante'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (_tracePoints.length < 2) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ajoutez au moins 2 points pour valider le tracé',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_isValidated) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tracé validé et prêt pour la configuration avancée',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ],
        ),
      ),
    ),
  ],
    );
  }

  // Afficher l'aide sur les modes de tracé (long-press)
  void _showTraceModeHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Modes de tracé'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeHelpItem(
              icon: Icons.gesture,
              title: 'Manuel',
              description: 'Cliquez sur la carte pour ajouter des points un par un. Contrôle total sur le tracé.',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildModeHelpItem(
              icon: Icons.alt_route,
              title: 'Suivre routes',
              description: 'Les points sont automatiquement alignés sur les routes existantes.',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildModeHelpItem(
              icon: Icons.straight,
              title: 'Ligne droite',
              description: 'Les points sont reliés par des lignes droites, ignorant les routes.',
              color: Colors.orange,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeHelpItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onLongPress: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎯 $tooltip'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.lerp(color, Colors.black, 0.7)!,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  String _getTraceModeDescription() {
    switch (_traceMode) {
      case 'manual':
        return 'Placez les points librement sur la carte pour un contrôle total';
      case 'follow_roads':
        return 'Le tracé suit automatiquement les routes entre les points';
      case 'straight':
        return 'Lignes droites entre les points, idéal pour les parcours hors sentiers';
      default:
        return '';
    }
  }

  void _centerOnLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Centrage sur la position actuelle...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _undoLastPoint() {
    setState(() {
      if (_tracePoints.isNotEmpty) {
        _tracePoints.removeLast();
        _recalculateStats();
        _isValidated = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dernier point supprimé'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _clearTrace() {
    setState(() {
      _tracePoints.clear();
      _totalDistance = 0.0;
      _elevationGain = 0.0;
      _elevationLoss = 0.0;
      _isValidated = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tracé effacé'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _addDemoPoint() {
    // Si mode déplacement et point sélectionné, déplacer le point
    if (_movePointMode && _selectedPointIndex != null) {
      final baseLat = 16.2500 + (_tracePoints.length * 0.002);
      final baseLng = -61.5833 + (_tracePoints.length * 0.002);
      
      setState(() {
        _tracePoints[_selectedPointIndex!] = {
          'lat': baseLat,
          'lng': baseLng,
          'elevation': _tracePoints[_selectedPointIndex!]['elevation'] ?? 50.0,
        };
        _recalculateStats();
        _isValidated = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Point ${_selectedPointIndex! + 1} déplacé'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    
    // Sinon, ajouter un nouveau point
    final baseLat = 16.2500 + (_tracePoints.length * 0.001);
    final baseLng = -61.5833 + (_tracePoints.length * 0.001);

    setState(() {
      _tracePoints.add({
        'lat': baseLat,
        'lng': baseLng,
        'elevation': 50.0 + (_tracePoints.length * 10),
      });
      _recalculateStats();
      _isValidated = false;
    });
  }

  void _recalculateStats() {
    // Calcul simplifié de la distance
    _totalDistance = _tracePoints.length * 0.5; // ~500m par point

    // Calcul du dénivelé
    _elevationGain = 0.0;
    _elevationLoss = 0.0;

    for (int i = 1; i < _tracePoints.length; i++) {
      final diff =
          (_tracePoints[i]['elevation'] ?? 0.0) -
          (_tracePoints[i - 1]['elevation'] ?? 0.0);
      if (diff > 0) {
        _elevationGain += diff;
      } else {
        _elevationLoss += diff.abs();
      }
    }
  }

  void _exportTraceToJson() {
    // Export simulé
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Export JSON: coordonnées copiées dans le presse-papier',
        ),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'Voir',
          textColor: Colors.white,
          onPressed: () {
            // Afficher un dialog avec le JSON
          },
        ),
      ),
    );
  }
}

// --- Step 4: Verrouiller & segments (10/10 Premium) ---
class _StepVerrouSegment extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;
  const _StepVerrouSegment({required this.onNext, required this.onPrev});

  @override
  State<_StepVerrouSegment> createState() => _StepVerrouSegmentState();
}

class _StepVerrouSegmentState extends State<_StepVerrouSegment> {
  bool _isLocked = false;
  final List<Map<String, dynamic>> _segments = [];
  
  // Configuration des flèches directionnelles
  bool _showArrows = true;
  double _arrowSpacing = 50.0; // mètres
  double _arrowSize = 1.0;
  String _arrowStyle = 'chevron'; // 'chevron', 'triangle', 'dot'
  Color _arrowColor = Colors.blue;

  // Styles disponibles
  final List<Map<String, dynamic>> _lineStyles = [
    {'id': 'solid', 'name': 'Continu', 'icon': Icons.remove},
    {'id': 'dashed', 'name': 'Tirets', 'icon': Icons.linear_scale},
    {'id': 'dotted', 'name': 'Pointillés', 'icon': Icons.more_horiz},
  ];
  
  final List<Map<String, dynamic>> _arrowStyles = [
    {'id': 'chevron', 'name': 'Chevron', 'icon': Icons.arrow_forward_ios},
    {'id': 'triangle', 'name': 'Triangle', 'icon': Icons.play_arrow},
    {'id': 'dot', 'name': 'Point', 'icon': Icons.fiber_manual_record},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Aperçu carte en direct
        _MapPreviewWidget(
          title: 'Aperçu des segments',
          segments: _segments,
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade50, Colors.purple.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.segment, color: Colors.purple.shade700, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Segments & Verrouillage',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Divisez le tracé en sections stylisées',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Verrouillage
                Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isLocked ? Icons.lock : Icons.lock_open,
                        color: _isLocked ? Colors.red : Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLocked
                                  ? 'Circuit verrouillé'
                                  : 'Circuit déverrouillé',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLocked
                                  ? 'Le tracé ne peut plus être modifié'
                                  : 'Le tracé peut encore être modifié',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isLocked,
                        onChanged: (value) {
                          setState(() => _isLocked = value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Circuit verrouillé - Création de segments possible'
                                    : 'Circuit déverrouillé',
                              ),
                              backgroundColor: value
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (!_isLocked) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Verrouillez le circuit pour créer des segments',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section Flèches directionnelles
          if (_isLocked) ...[
            Text(
              'Flèches directionnelles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      value: _showArrows,
                      onChanged: (value) {
                        setState(() => _showArrows = value);
                      },
                      title: const Text('Afficher les flèches'),
                      subtitle: const Text('Indique le sens de parcours'),
                      secondary: const Icon(Icons.arrow_forward),
                    ),
                    
                    if (_showArrows) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      
                      Text(
                        'Style des flèches',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Wrap(
                        spacing: 8,
                        children: _arrowStyles.map((style) {
                          final isSelected = _arrowStyle == style['id'];
                          return FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  style['icon'],
                                  size: 16,
                                  color: isSelected ? Colors.white : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(style['name']),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _arrowStyle = style['id']);
                            },
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        'Espacement: ${_arrowSpacing.toInt()} mètres',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Slider(
                        value: _arrowSpacing,
                        min: 20,
                        max: 200,
                        divisions: 18,
                        label: '${_arrowSpacing.toInt()}m',
                        onChanged: (value) {
                          setState(() => _arrowSpacing = value);
                        },
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Taille: ${(_arrowSize * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Slider(
                        value: _arrowSize,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        label: '${(_arrowSize * 100).toInt()}%',
                        onChanged: (value) {
                          setState(() => _arrowSize = value);
                        },
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Couleur des flèches',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      Wrap(
                        spacing: 8,
                        children: [
                          Colors.blue,
                          Colors.red,
                          Colors.green,
                          Colors.orange,
                          Colors.purple,
                          Colors.black,
                          Colors.white,
                        ].map((color) {
                          return GestureDetector(
                            onTap: () => setState(() => _arrowColor = color),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _arrowColor == color
                                      ? Colors.black
                                      : Colors.grey.shade300,
                                  width: _arrowColor == color ? 3 : 1,
                                ),
                              ),
                              child: _arrowColor == color
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
          
          // Sections des segments
          if (_isLocked) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Segments du circuit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _addSegment(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter segment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Les segments permettent d\'appliquer des styles différents sur des portions du tracé',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_segments.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.segment,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun segment créé',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cliquez sur "Ajouter segment" pour commencer',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _segments.length,
                itemBuilder: (context, index) {
                  final segment = _segments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: segment['color'],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      segment['name'],
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          _getStyleIcon(segment['style']),
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getStyleName(segment['style']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.line_weight,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${segment['width']}px',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editSegment(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                color: Colors.red,
                                onPressed: () {
                                  setState(() => _segments.removeAt(index));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Segment supprimé'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),
          ],

          // Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onPrev,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Étape précédente'),
              ),
              ElevatedButton.icon(
                onPressed: _isLocked ? widget.onNext : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Étape suivante'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),

          if (!_isLocked) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verrouillez le circuit pour passer à l\'étape suivante',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        ),
      ),
    ),
  ],
    );
  }

  IconData _getStyleIcon(String style) {
    switch (style) {
      case 'solid':
        return Icons.remove;
      case 'dashed':
        return Icons.linear_scale;
      case 'dotted':
        return Icons.more_horiz;
      default:
        return Icons.remove;
    }
  }

  String _getStyleName(String style) {
    switch (style) {
      case 'solid':
        return 'Continu';
      case 'dashed':
        return 'Tirets';
      case 'dotted':
        return 'Pointillés';
      default:
        return 'Continu';
    }
  }

  void _addSegment() {
    _showSegmentDialog();
  }

  void _editSegment(int index) {
    _showSegmentDialog(segmentIndex: index);
  }

  void _showSegmentDialog({int? segmentIndex}) {
    final isEdit = segmentIndex != null;
    final segment = isEdit ? _segments[segmentIndex] : null;

    String name = segment?['name'] ?? 'Segment ${_segments.length + 1}';
    Color color = segment?['color'] ?? Colors.blue;
    String style = segment?['style'] ?? 'solid';
    double width = segment?['width'] ?? 4.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Modifier le segment' : 'Nouveau segment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nom du segment',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: name),
                  onChanged: (value) => name = value,
                ),
                const SizedBox(height: 16),

                // Couleur
                const Text(
                  'Couleur',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      [
                        Colors.red,
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.deepPurple,
                        Colors.cyan,
                        Colors.teal,
                        Colors.amber,
                      ].map((c) {
                        return GestureDetector(
                          onTap: () => setDialogState(() => color = c),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: color == c
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),

                // Style
                const Text(
                  'Style de ligne',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: _lineStyles
                      .map(
                        (s) => ButtonSegment<String>(
                          value: s['id'],
                          label: Text(s['name']),
                          icon: Icon(s['icon']),
                        ),
                      )
                      .toList(),
                  selected: {style},
                  onSelectionChanged: (Set<String> newSelection) {
                    setDialogState(() => style = newSelection.first);
                  },
                ),
                const SizedBox(height: 16),

                // Épaisseur
                Text(
                  'Épaisseur: ${width.toStringAsFixed(0)}px',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: width,
                  min: 2,
                  max: 10,
                  divisions: 8,
                  label: '${width.toStringAsFixed(0)}px',
                  onChanged: (value) => setDialogState(() => width = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final newSegment = {
                    'name': name,
                    'color': color,
                    'style': style,
                    'width': width,
                  };
                  if (isEdit) {
                    _segments[segmentIndex] = newSegment;
                  } else {
                    _segments.add(newSegment);
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit ? 'Segment modifié' : 'Segment ajouté',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text(isEdit ? 'Modifier' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Step 5: Publier (10/10 Premium) ---
class _StepPublier extends StatefulWidget {
  final VoidCallback onPrev;
  const _StepPublier({required this.onPrev});

  @override
  State<_StepPublier> createState() => _StepPublierState();
}

class _StepPublierState extends State<_StepPublier> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _visibility = 'public'; // public, private, unlisted
  String _category = 'randonnee';
  String _difficulty = 'facile';
  int _estimatedDuration = 60; // minutes

  final List<String> _tags = [];
  final _tagController = TextEditingController();

  bool _termsAccepted = false;
  bool _dataVerified = false;
  bool _isPublishing = false;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'randonnee', 'name': 'Randonnée', 'icon': Icons.hiking},
    {'id': 'velo', 'name': 'Vélo', 'icon': Icons.pedal_bike},
    {'id': 'course', 'name': 'Course', 'icon': Icons.directions_run},
    {'id': 'patrimoine', 'name': 'Patrimoine', 'icon': Icons.account_balance},
    {'id': 'nature', 'name': 'Nature', 'icon': Icons.nature},
    {'id': 'urbain', 'name': 'Urbain', 'icon': Icons.location_city},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Aperçu final de la carte (affichage conditonnel)
        Container(
          height: 300,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'Aperçu final du circuit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enregistrez pour visualiser sur la carte',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.publish, color: Colors.green.shade700, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                        'Publication du circuit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dernière étape avant la mise en ligne',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Informations générales
          Text(
            'Informations générales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom du circuit *',
              hintText: 'Ex: Tour des Trois Îlets',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText:
                  'Décrivez le circuit, ses points d\'intérêt, sa difficulté...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 24),

          // Catégorie
          Text(
            'Catégorie',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final isSelected = _category == cat['id'];
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat['icon'],
                      size: 18,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(cat['name']),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _category = cat['id']);
                },
                selectedColor: Colors.blue,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Difficulté
          Text(
            'Difficulté',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'facile',
                label: Text('Facile'),
                icon: Icon(Icons.sentiment_satisfied),
              ),
              ButtonSegment(
                value: 'moyen',
                label: Text('Moyen'),
                icon: Icon(Icons.sentiment_neutral),
              ),
              ButtonSegment(
                value: 'difficile',
                label: Text('Difficile'),
                icon: Icon(Icons.sentiment_dissatisfied),
              ),
            ],
            selected: {_difficulty},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _difficulty = newSelection.first);
            },
          ),

          const SizedBox(height: 24),

          // Durée estimée
          Text(
            'Durée estimée: $_estimatedDuration minutes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Slider(
            value: _estimatedDuration.toDouble(),
            min: 15,
            max: 480,
            divisions: 31,
            label: '$_estimatedDuration min',
            onChanged: (value) {
              setState(() => _estimatedDuration = value.toInt());
            },
          ),

          const SizedBox(height: 24),

          // Visibilité
          Text(
            'Visibilité',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'public',
                  groupValue: _visibility,
                  onChanged: (value) => setState(() => _visibility = value!),
                  title: const Text('Public'),
                  subtitle: const Text('Visible par tous les utilisateurs'),
                  secondary: const Icon(Icons.public),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'unlisted',
                  groupValue: _visibility,
                  onChanged: (value) => setState(() => _visibility = value!),
                  title: const Text('Non répertorié'),
                  subtitle: const Text('Accessible uniquement via le lien'),
                  secondary: const Icon(Icons.link),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'private',
                  groupValue: _visibility,
                  onChanged: (value) => setState(() => _visibility = value!),
                  title: const Text('Privé'),
                  subtitle: const Text('Uniquement vous'),
                  secondary: const Icon(Icons.lock),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tags
          Text(
            'Tags',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des mots-clés pour faciliter la recherche',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau tag',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  onSubmitted: (value) => _addTag(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addTag,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),

          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _tags.remove(tag));
                  },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 24),

          // Résumé de la configuration
          Text(
            'Résumé du circuit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.check_circle,
                  'Périmètre défini',
                  Colors.green,
                ),
                const Divider(),
                _buildSummaryRow(
                  Icons.map,
                  'Carte offline configurée',
                  Colors.green,
                ),
                const Divider(),
                _buildSummaryRow(Icons.route, 'Tracé validé', Colors.green),
                const Divider(),
                _buildSummaryRow(Icons.segment, 'Segments créés', Colors.green),
                const Divider(),
                _buildSummaryRow(Icons.publish, 'Prêt à publier', Colors.blue),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Checklist finale
          Text(
            'Checklist finale',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  value: _dataVerified,
                  onChanged: (value) => setState(() => _dataVerified = value!),
                  title: const Text('J\'ai vérifié toutes les données'),
                  subtitle: const Text('Tracé, segments, informations'),
                ),
                const Divider(height: 1),
                CheckboxListTile(
                  value: _termsAccepted,
                  onChanged: (value) => setState(() => _termsAccepted = value!),
                  title: const Text('J\'accepte les conditions'),
                  subtitle: const Text('Charte de publication des circuits'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Boutons d'action
          if (!_isPublishing) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onPrev,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Étape précédente'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _canPublish() ? _publishCircuit : null,
                    icon: const Icon(Icons.publish),
                    label: const Text('Publier le circuit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saveAsDraft,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer comme brouillon'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ] else ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Publication en cours...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],

          if (!_canPublish()) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getPublishError(),
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        ),
      ),
    ),
  ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color.lerp(color, Colors.black, 0.5)!,
            ),
          ),
        ),
      ],
    );
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  bool _canPublish() {
    return _nameController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _termsAccepted &&
        _dataVerified;
  }

  String _getPublishError() {
    if (_nameController.text.trim().isEmpty) {
      return 'Veuillez saisir un nom pour le circuit';
    }
    if (_descriptionController.text.trim().isEmpty) {
      return 'Veuillez saisir une description';
    }
    if (!_dataVerified) {
      return 'Veuillez vérifier les données';
    }
    if (!_termsAccepted) {
      return 'Veuillez accepter les conditions';
    }
    return '';
  }

  Future<void> _publishCircuit() async {
    setState(() => _isPublishing = true);

    // Simulation de publication
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _isPublishing = false);

    // Afficher confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Circuit publié !'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le circuit "${_nameController.text}" a été publié avec succès.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Détails:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('• Visibilité: ${_getVisibilityLabel()}'),
                  Text('• Catégorie: ${_getCategoryLabel()}'),
                  Text('• Difficulté: ${_getDifficultyLabel()}'),
                  Text('• Durée: $_estimatedDuration min'),
                  if (_tags.isNotEmpty) Text('• Tags: ${_tags.join(", ")}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fermer dialog
              Navigator.pop(context); // Retour au dashboard
            },
            child: const Text('Retour au dashboard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Aller vers la page du circuit
            },
            child: const Text('Voir le circuit'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsDraft() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Circuit enregistré comme brouillon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _getVisibilityLabel() {
    switch (_visibility) {
      case 'public':
        return 'Public';
      case 'unlisted':
        return 'Non répertorié';
      case 'private':
        return 'Privé';
      default:
        return '';
    }
  }

  String _getCategoryLabel() {
    final cat = _categories.firstWhere((c) => c['id'] == _category);
    return cat['name'];
  }

  String _getDifficultyLabel() {
    switch (_difficulty) {
      case 'facile':
        return 'Facile';
      case 'moyen':
        return 'Moyen';
      case 'difficile':
        return 'Difficile';
      default:
        return '';
    }
  }
}

// Dialog pour configurer un bâtiment spécifique
class _BuildingConfigDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSave;

  const _BuildingConfigDialog({this.initialData, required this.onSave});

  @override
  State<_BuildingConfigDialog> createState() => _BuildingConfigDialogState();
}

class _BuildingConfigDialogState extends State<_BuildingConfigDialog> {
  late TextEditingController _nameController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _photoUrlController;

  String _facadeTexture = 'windows_modern';
  String _roofTexture = 'concrete';
  double _scale = 1.0;
  bool _hasCustomPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialData?['name'] ?? '',
    );
    _latController = TextEditingController(
      text: widget.initialData?['lat']?.toString() ?? '16.2500',
    );
    _lngController = TextEditingController(
      text: widget.initialData?['lng']?.toString() ?? '-61.5833',
    );
    _photoUrlController = TextEditingController(
      text: widget.initialData?['facadePhotoUrl'] ?? '',
    );
    _facadeTexture = widget.initialData?['facadeTexture'] ?? 'windows_modern';
    _roofTexture = widget.initialData?['roofTexture'] ?? 'concrete';
    _scale = widget.initialData?['scale'] ?? 1.0;
    _hasCustomPhoto = widget.initialData?['facadePhotoUrl'] != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade600, Colors.indigo.shade800],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.initialData == null
                          ? 'Ajouter un bâtiment'
                          : 'Modifier le bâtiment',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Contenu scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identification
                    Text(
                      'Identification',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom du bâtiment',
                        hintText: 'Ex: Cathédrale, Mairie...',
                        prefixIcon: const Icon(Icons.label),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            decoration: InputDecoration(
                              labelText: 'Latitude',
                              prefixIcon: const Icon(Icons.location_on),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lngController,
                            decoration: InputDecoration(
                              labelText: 'Longitude',
                              prefixIcon: const Icon(Icons.location_on),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Photo personnalisée
                    Text(
                      'Photo de façade (optionnel)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _hasCustomPhoto,
                      onChanged: (value) {
                        setState(() {
                          _hasCustomPhoto = value;
                          if (!value) _photoUrlController.clear();
                        });
                      },
                      title: const Text('Utiliser une photo personnalisée'),
                      subtitle: const Text(
                        'Appliquée sur les façades de ce bâtiment',
                      ),
                      activeThumbColor: Colors.indigo,
                    ),
                    if (_hasCustomPhoto) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _photoUrlController,
                        decoration: InputDecoration(
                          labelText: 'URL de la photo',
                          hintText: 'https://example.com/facade.jpg',
                          prefixIcon: const Icon(Icons.link),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.image),
                            onPressed: () {
                              // Simulation: générer une URL de démo
                              _photoUrlController.text =
                                  'https://picsum.photos/512/512?random=${DateTime.now().millisecondsSinceEpoch}';
                              setState(() {});
                            },
                            tooltip: 'Générer une image de test',
                          ),
                        ),
                      ),
                      if (_photoUrlController.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _photoUrlController.text,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),

                    // Textures
                    if (!_hasCustomPhoto) ...[
                      Text(
                        'Texture de façade',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _facadeTexture,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.texture),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'windows_modern',
                            child: Text('🏢 Fenêtres modernes'),
                          ),
                          DropdownMenuItem(
                            value: 'windows_classic',
                            child: Text('🏛️ Fenêtres classiques'),
                          ),
                          DropdownMenuItem(
                            value: 'brick_red',
                            child: Text('🧱 Brique rouge'),
                          ),
                          DropdownMenuItem(
                            value: 'brick_brown',
                            child: Text('🟫 Brique marron'),
                          ),
                          DropdownMenuItem(
                            value: 'concrete',
                            child: Text('⬜ Béton'),
                          ),
                          DropdownMenuItem(
                            value: 'glass_blue',
                            child: Text('💎 Verre bleuté'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _facadeTexture = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      'Texture de toit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _roofTexture,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.roofing),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'concrete',
                          child: Text('⬜ Béton'),
                        ),
                        DropdownMenuItem(
                          value: 'tiles_red',
                          child: Text('🔴 Tuiles rouges'),
                        ),
                        DropdownMenuItem(
                          value: 'tiles_brown',
                          child: Text('🟤 Tuiles brunes'),
                        ),
                        DropdownMenuItem(
                          value: 'slate',
                          child: Text('⬛ Ardoise'),
                        ),
                        DropdownMenuItem(
                          value: 'metal_gray',
                          child: Text('🔧 Métal gris'),
                        ),
                        DropdownMenuItem(
                          value: 'green_roof',
                          child: Text('🌿 Toit végétalisé'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _roofTexture = value);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Échelle
                    Text(
                      'Échelle de la texture: ${_scale.toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Slider(
                      value: _scale,
                      min: 0.5,
                      max: 3.0,
                      divisions: 25,
                      label: '${_scale.toStringAsFixed(1)}x',
                      onChanged: (value) {
                        setState(() => _scale = value);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final lat = double.tryParse(_latController.text);
                      final lng = double.tryParse(_lngController.text);

                      if (lat == null || lng == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Coordonnées invalides'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final buildingData = {
                        'name': _nameController.text.isEmpty
                            ? 'Bâtiment'
                            : _nameController.text,
                        'lat': lat,
                        'lng': lng,
                        'facadeTexture': _facadeTexture,
                        'roofTexture': _roofTexture,
                        'scale': _scale,
                        if (_hasCustomPhoto &&
                            _photoUrlController.text.isNotEmpty)
                          'facadePhotoUrl': _photoUrlController.text,
                      };

                      widget.onSave(buildingData);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Enregistrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Mini-Map Preview Widget ---
class _MiniMapPreview extends StatelessWidget {
  final List<Map<String, double>> routePoints;
  final Function(int)? onPointTap;

  const _MiniMapPreview({
    required this.routePoints,
    this.onPointTap,
  });

  @override
  Widget build(BuildContext context) {
    if (routePoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onLongPress: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💡 Tap sur un point pour le déplacer'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            
            // Grid pattern
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(),
            ),

            // Route visualization
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                size: Size.infinite,
                painter: _RoutePainter(routePoints: routePoints),
              ),
            ),

            // Points overlay
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        for (int i = 0; i < routePoints.length; i++)
                          _buildPointMarker(context, i, constraints),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Info overlay
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Mini-carte (${routePoints.length} points)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Long-press hint
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Long-press pour aide',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointMarker(
    BuildContext context,
    int index,
    BoxConstraints constraints,
  ) {
    final point = routePoints[index];
    final normalizedPos = _normalizePoint(point, constraints);
    
    final isFirst = index == 0;
    final isLast = index == routePoints.length - 1;

    return Positioned(
      left: normalizedPos.dx - 8,
      top: normalizedPos.dy - 8,
      child: GestureDetector(
        onTap: () => onPointTap?.call(index),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isFirst
                ? Colors.green
                : isLast
                    ? Colors.red
                    : Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isFirst
                  ? Icons.play_arrow
                  : isLast
                      ? Icons.flag
                      : Icons.circle,
              size: isFirst || isLast ? 10 : 6,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Offset _normalizePoint(Map<String, double> point, BoxConstraints constraints) {
    // Simple normalization for demo - in production use real map projection
    final lat = point['lat'] ?? 0.0;
    final lng = point['lng'] ?? 0.0;
    
    // Find bounds
    double minLat = routePoints.first['lat']!;
    double maxLat = minLat;
    double minLng = routePoints.first['lng']!;
    double maxLng = minLng;
    
    for (final p in routePoints) {
      final pLat = p['lat']!;
      final pLng = p['lng']!;
      if (pLat < minLat) minLat = pLat;
      if (pLat > maxLat) maxLat = pLat;
      if (pLng < minLng) minLng = pLng;
      if (pLng > maxLng) maxLng = pLng;
    }
    
    // Add padding
    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    
    final normalizedX = lngRange > 0
        ? ((lng - minLng) / lngRange) * constraints.maxWidth
        : constraints.maxWidth / 2;
    final normalizedY = latRange > 0
        ? ((maxLat - lat) / latRange) * constraints.maxHeight
        : constraints.maxHeight / 2;
    
    return Offset(normalizedX, normalizedY);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // Vertical lines
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  final List<Map<String, double>> routePoints;

  _RoutePainter({required this.routePoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.shade700
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Normalize first point
    final firstPoint = _normalizePoint(routePoints.first, size);
    path.moveTo(firstPoint.dx, firstPoint.dy);
    
    // Draw line through all points
    for (int i = 1; i < routePoints.length; i++) {
      final point = _normalizePoint(routePoints[i], size);
      path.lineTo(point.dx, point.dy);
    }
    
    canvas.drawPath(path, paint);
  }

  Offset _normalizePoint(Map<String, double> point, Size size) {
    final lat = point['lat'] ?? 0.0;
    final lng = point['lng'] ?? 0.0;
    
    // Find bounds
    double minLat = routePoints.first['lat']!;
    double maxLat = minLat;
    double minLng = routePoints.first['lng']!;
    double maxLng = minLng;
    
    for (final p in routePoints) {
      final pLat = p['lat']!;
      final pLng = p['lng']!;
      if (pLat < minLat) minLat = pLat;
      if (pLat > maxLat) maxLat = pLat;
      if (pLng < minLng) minLng = pLng;
      if (pLng > maxLng) maxLng = pLng;
    }
    
    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    
    final normalizedX = lngRange > 0
        ? ((lng - minLng) / lngRange) * size.width
        : size.width / 2;
    final normalizedY = latRange > 0
        ? ((maxLat - lat) / latRange) * size.height
        : size.height / 2;
    
    return Offset(normalizedX, normalizedY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


// Widget de prévisualisation de carte pour toutes les étapes
class _MapPreviewWidget extends StatelessWidget {
  final String title;
  final List<Map<String, double>>? polygonPoints;
  final List<Map<String, double>>? routePoints;
  final String? selectedPreset;
  final String? presetName;
  final String? selectedStyle;
  final List<Map<String, dynamic>>? segments;

  const _MapPreviewWidget({
    required this.title,
    this.polygonPoints,
    this.routePoints,
    this.selectedPreset,
    this.presetName,
    this.selectedStyle,
    this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final useMapbox = kIsWeb && _mapboxToken.isNotEmpty;

    return Container(
      height: 660,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade100, Colors.grey.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (useMapbox)
              MapboxWebView(
                accessToken: _mapboxToken,
                initialLat: (polygonPoints?.isNotEmpty ?? false)
                    ? polygonPoints!.first['lat'] ?? 16.241
                    : 16.241,
                initialLng: (polygonPoints?.isNotEmpty ?? false)
                    ? polygonPoints!.first['lng'] ?? -61.534
                    : -61.534,
                initialZoom: 11.8,
                styleUrl: 'mapbox://styles/mapbox/outdoors-v12',
              )
            else
              CustomPaint(
                painter: _GridPainter(),
                child: Container(),
              ),
            
            // Dessiner le périmètre si présent
            if (!useMapbox && polygonPoints != null && polygonPoints!.isNotEmpty)
              CustomPaint(
                painter: _PolygonPreviewPainter(points: polygonPoints!),
              ),
            
            // Dessiner le tracé si présent
            if (!useMapbox && routePoints != null && routePoints!.isNotEmpty)
              CustomPaint(
                painter: _RoutePreviewPainter(points: routePoints!),
              ),
            
            // Dessiner les segments si présents
            if (!useMapbox && segments != null && segments!.isNotEmpty)
              CustomPaint(
                painter: _SegmentsPreviewPainter(segments: segments!),
              ),
            
            // Header avec titre
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Informations overlay avec statut Mapbox
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildInfoText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: useMapbox 
                          ? Colors.green.shade700.withOpacity(0.8)
                          : Colors.orange.shade700.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          useMapbox ? Icons.cloud_done : Icons.cloud_off,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          useMapbox ? 'Mapbox' : 'Aperçu',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoText() {
    final infos = <String>[];
    
    if (polygonPoints != null && polygonPoints!.isNotEmpty) {
      infos.add('${polygonPoints!.length} points périmètre');
    }
    if (selectedPreset != null && presetName != null) {
      infos.add('Zone: $presetName');
    }
    if (routePoints != null && routePoints!.isNotEmpty) {
      infos.add('${routePoints!.length} points tracé');
    }
    if (selectedStyle != null) {
      infos.add('Style: $selectedStyle');
    }
    if (segments != null && segments!.isNotEmpty) {
      infos.add('${segments!.length} segments');
    }
    
    if (infos.isEmpty) {
      return const Text(
        'Aucune donnée',
        style: TextStyle(color: Colors.white70, fontSize: 11),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: infos.map((info) => Text(
        info,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      )).toList(),
    );
  }
}

// Painter pour le périmètre en preview
class _PolygonPreviewPainter extends CustomPainter {
  final List<Map<String, double>> points;

  _PolygonPreviewPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Fill
    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Stroke
    final strokePaint = Paint()
      ..color = Colors.blue.shade700
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final firstPoint = _normalizePoint(points.first, size);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    for (int i = 1; i < points.length; i++) {
      final point = _normalizePoint(points[i], size);
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Draw points
    final pointPaint = Paint()
      ..color = Colors.blue.shade900
      ..style = PaintingStyle.fill;

    for (final point in points) {
      final normalized = _normalizePoint(point, size);
      canvas.drawCircle(normalized, 4, pointPaint);
    }
  }

  Offset _normalizePoint(Map<String, double> point, Size size) {
    final lat = point['lat'] ?? 0.0;
    final lng = point['lng'] ?? 0.0;

    double minLat = points.first['lat']!;
    double maxLat = minLat;
    double minLng = points.first['lng']!;
    double maxLng = minLng;

    for (final p in points) {
      final pLat = p['lat']!;
      final pLng = p['lng']!;
      if (pLat < minLat) minLat = pLat;
      if (pLat > maxLat) maxLat = pLat;
      if (pLng < minLng) minLng = pLng;
      if (pLng > maxLng) maxLng = pLng;
    }

    final latRange = (maxLat - minLat).abs();
    final lngRange = (maxLng - minLng).abs();
    
    // Add padding
    final padding = 20.0;
    final normalizedX = lngRange > 0
        ? padding + ((lng - minLng) / lngRange) * (size.width - 2 * padding)
        : size.width / 2;
    final normalizedY = latRange > 0
        ? padding + ((maxLat - lat) / latRange) * (size.height - 2 * padding)
        : size.height / 2;

    return Offset(normalizedX, normalizedY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Painter pour le tracé en preview
class _RoutePreviewPainter extends CustomPainter {
  final List<Map<String, double>> points;

  _RoutePreviewPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = Colors.teal.shade700
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final firstPoint = _normalizePoint(points.first, size);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    for (int i = 1; i < points.length; i++) {
      final point = _normalizePoint(points[i], size);
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = Colors.teal.shade900
      ..style = PaintingStyle.fill;

    for (final point in points) {
      final normalized = _normalizePoint(point, size);
      canvas.drawCircle(normalized, 3, pointPaint);
    }
  }

  Offset _normalizePoint(Map<String, double> point, Size size) {
    final lat = point['lat'] ?? 0.0;
    final lng = point['lng'] ?? 0.0;

    double minLat = points.first['lat']!;
    double maxLat = minLat;
    double minLng = points.first['lng']!;
    double maxLng = minLng;

    for (final p in points) {
      final pLat = p['lat']!;
      final pLng = p['lng']!;
      if (pLat < minLat) minLat = pLat;
      if (pLat > maxLat) maxLat = pLat;
      if (pLng < minLng) minLng = pLng;
      if (pLng > maxLng) maxLng = pLng;
    }

    final latRange = (maxLat - minLat).abs();
    final lngRange = (maxLng - minLng).abs();
    
    final padding = 20.0;
    final normalizedX = lngRange > 0
        ? padding + ((lng - minLng) / lngRange) * (size.width - 2 * padding)
        : size.width / 2;
    final normalizedY = latRange > 0
        ? padding + ((maxLat - lat) / latRange) * (size.height - 2 * padding)
        : size.height / 2;

    return Offset(normalizedX, normalizedY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Painter pour les segments en preview
class _SegmentsPreviewPainter extends CustomPainter {
  final List<Map<String, dynamic>> segments;

  _SegmentsPreviewPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    for (final segment in segments) {
      final color = segment['color'] as Color? ?? Colors.red;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Simuler des segments aléatoires
      final startX = (segment.hashCode % size.width.toInt()).toDouble();
      final startY = (segment.hashCode % size.height.toInt()).toDouble();
      final endX = ((segment.hashCode + 100) % size.width.toInt()).toDouble();
      final endY = ((segment.hashCode + 100) % size.height.toInt()).toDouble();

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

*/
