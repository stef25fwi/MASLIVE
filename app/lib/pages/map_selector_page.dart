import 'package:flutter/material.dart';
import '../models/map_preset_model.dart';
import '../services/map_presets_service.dart';
import '../ui/theme/maslive_theme.dart';

/// Page pour sélectionner une carte pré-enregistrée et ses couches
/// Seuls les superadmins peuvent modifier la sélection.
/// Les autres utilisateurs ne peuvent que consulter.
class MapSelectorPage extends StatefulWidget {
  final String groupId;
  final Function(MapPresetModel selectedPreset, List<LayerModel> visibleLayers)
      onMapSelected;
  final MapPresetModel? initialPreset;
  final bool isReadOnly;

  const MapSelectorPage({
    super.key,
    required this.groupId,
    required this.onMapSelected,
    this.initialPreset,
    this.isReadOnly = false,
  });

  @override
  State<MapSelectorPage> createState() => _MapSelectorPageState();
}

class _MapSelectorPageState extends State<MapSelectorPage> {
  late MapPresetsService _service;
  MapPresetModel? _selectedPreset;
  Map<String, bool> _layerVisibility = {};

  @override
  void initState() {
    super.initState();
    _service = MapPresetsService();
    _selectedPreset = widget.initialPreset;
    _initializeLayerVisibility();
  }

  void _initializeLayerVisibility() {
    if (_selectedPreset != null) {
      _layerVisibility = {
        for (var layer in _selectedPreset!.layers) layer.id: layer.visible
      };
    }
  }

  void _toggleLayerVisibility(String layerId) {
    if (widget.isReadOnly) return;
    setState(() {
      _layerVisibility[layerId] = !(_layerVisibility[layerId] ?? false);
    });
  }

  void _applySelection() {
    if (widget.isReadOnly) {
      Navigator.pop(context);
      return;
    }
    
    if (_selectedPreset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une carte')),
      );
      return;
    }

    final visibleLayers = _selectedPreset!.layers
        .where((layer) => _layerVisibility[layer.id] ?? false)
        .toList();

    widget.onMapSelected(_selectedPreset!, visibleLayers);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFB66CFF);
    
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: MasliveTheme.headerGradient,
              borderRadius: BorderRadius.circular(0),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isReadOnly
                                  ? 'Carte active'
                                  : 'Sélectionner une carte',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            Text(
                              widget.isReadOnly
                                  ? 'Vous consultez la carte sélectionnée'
                                  : 'Choisissez une carte et ses couches',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MapPresetModel>>(
              stream: _service.getGroupPresetsStream(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune carte disponible',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Créez une carte depuis l\'éditeur',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  );
                }

                final presets = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    final preset = presets[index];
                    final isSelected = _selectedPreset?.id == preset.id;

                    return _PresetCard(
                      preset: preset,
                      isSelected: isSelected,
                      onTap: () {
                        if (widget.isReadOnly) return;
                        setState(() {
                          _selectedPreset = preset;
                          _initializeLayerVisibility();
                        });
                      },
                      layers: preset.layers,
                      layerVisibility: _layerVisibility,
                      onLayerToggle: _toggleLayerVisibility,
                      accentColor: accentColor,
                      isReadOnly: widget.isReadOnly,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applySelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.isReadOnly ? 'Fermer' : 'Appliquer',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte affichant un preset de carte
class _PresetCard extends StatefulWidget {
  final MapPresetModel preset;
  final bool isSelected;
  final VoidCallback onTap;
  final List<LayerModel> layers;
  final Map<String, bool> layerVisibility;
  final Function(String layerId) onLayerToggle;
  final Color accentColor;
  final bool isReadOnly;

  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
    required this.layers,
    required this.layerVisibility,
    required this.onLayerToggle,
    required this.accentColor,
    this.isReadOnly = false,
  });

  @override
  State<_PresetCard> createState() => _PresetCardState();
}

class _PresetCardState extends State<_PresetCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isReadOnly ? null : () {
        widget.onTap();
        if (widget.layers.isNotEmpty && !_isExpanded) {
          _toggleExpand();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSelected
                ? widget.accentColor
                : Colors.grey[700]!,
            width: widget.isSelected ? 2 : 1,
          ),
          color: widget.isSelected
              ? widget.accentColor.withAlpha(25)
              : Colors.grey[900],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Sélecteur radio
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accentColor,
                        width: 2,
                      ),
                    ),
                    child: widget.isSelected
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.accentColor,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Titre et description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.preset.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.preset.description.isNotEmpty)
                          Text(
                            widget.preset.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Nombre de couches
                  if (widget.layers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.layers.length} couche${widget.layers.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bouton d'expansion
                    RotatedBox(
                      quarterTurns: _isExpanded ? 2 : 0,
                      child: Icon(
                        Icons.expand_more,
                        color: widget.accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Couches (expansion)
            if (widget.layers.isNotEmpty)
              SizeTransition(
                sizeFactor: Tween<double>(begin: 0, end: 1)
                    .animate(_expandController),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey[800]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.layers.length,
                    itemBuilder: (context, index) {
                      final layer = widget.layers[index];
                      final isVisible = widget.layerVisibility[layer.id] ?? false;

                      return _LayerTile(
                        layer: layer,
                        isVisible: isVisible,
                        onToggle: () {
                          widget.onLayerToggle(layer.id);
                        },
                        accentColor: widget.accentColor,
                        isReadOnly: widget.isReadOnly,
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tuile pour chaque couche avec checkbox
class _LayerTile extends StatelessWidget {
  final LayerModel layer;
  final bool isVisible;
  final VoidCallback onToggle;
  final Color accentColor;
  final bool isReadOnly;

  const _LayerTile({
    required this.layer,
    required this.isVisible,
    required this.onToggle,
    required this.accentColor,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isReadOnly ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: isVisible,
              onChanged: isReadOnly ? null : (_) => onToggle(),
              activeColor: accentColor,
              checkColor: Colors.white,
            ),
            // Nom de la couche
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layer.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isVisible ? Colors.white : Colors.grey[500],
                    ),
                  ),
                  if (layer.description.isNotEmpty)
                    Text(
                      layer.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Type de couche (badge)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: _getLayerTypeColor(layer.type).withAlpha(51),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                layer.type,
                style: TextStyle(
                  fontSize: 10,
                  color: _getLayerTypeColor(layer.type),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLayerTypeColor(String type) {
    switch (type) {
      case 'circuits':
        return Colors.cyan;
      case 'pois':
        return Colors.lime;
      case 'routes':
        return Colors.orange;
      case 'geofence':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
