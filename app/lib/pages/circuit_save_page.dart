// ignore_for_file: unused_field, unused_element, dead_code

import 'package:flutter/material.dart';
import '../admin/create_circuit_assistant_page.dart';

class CircuitSavePage extends StatefulWidget {
  const CircuitSavePage({super.key});

  @override
  State<CircuitSavePage> createState() => _CircuitSavePageState();
}

class _CircuitSavePageState extends State<CircuitSavePage> {
  final Map<String, Map<String, dynamic>> _folders = {
    'Mes Circuits': {
      'maps': {
        'Circuit Côte Basse': {
          'enabled': true,
          'layers': {
            'Circuit': false,
            'Visiter': true,
            'Food': true,
            'Assistance': false,
            'Parking': true,
            'WC': false,
          }
        },
        'Circuit Pitons': {
          'enabled': true,
          'layers': {
            'Circuit': true,
            'Visiter': true,
            'Food': false,
            'Assistance': true,
            'Parking': false,
            'WC': true,
          }
        },
      }
    },
    'Circuits Favoris': {
      'maps': {
        'Boucle Guadeloupe': {
          'enabled': false,
          'layers': {
            'Circuit': true,
            'Visiter': false,
            'Food': true,
            'Assistance': true,
            'Parking': false,
            'WC': false,
          }
        },
      }
    },
  };

  final List<Map<String, dynamic>> _layers = [
    {'name': 'Circuit', 'icon': Icons.route, 'color': Color(0xFF1A73E8)},
    {'name': 'Visiter', 'icon': Icons.tour, 'color': Color(0xFFF59E0B)},
    {'name': 'Food', 'icon': Icons.restaurant, 'color': Color(0xFFEF4444)},
    {'name': 'Assistance', 'icon': Icons.support_agent, 'color': Color(0xFF34A853)},
    {'name': 'Parking', 'icon': Icons.local_parking, 'color': Color(0xFFFBBF24)},
    {'name': 'WC', 'icon': Icons.wc, 'color': Color(0xFF9333EA)},
  ];

  String? _expandedFolder;
  String? _expandedMap;

  void _createFolder() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateFolderDialog(
        onSave: (name) {
          setState(() {
            _folders[name] = {'maps': {}};
          });
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✓ Dossier '$name' créé")),
          );
        },
      ),
    );
  }

  void _deleteFolder(String folderName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le dossier ?"),
        content: Text("'$folderName' et tous ses circuits seront supprimés."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              setState(() => _folders.remove(folderName));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("✓ Dossier '$folderName' supprimé")),
              );
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleMap(String folder, String mapName) {
    setState(() {
      _folders[folder]!['maps'][mapName]['enabled'] =
          !_folders[folder]!['maps'][mapName]['enabled'];
    });
  }

  void _toggleLayer(String folder, String mapName, String layerName) {
    setState(() {
      _folders[folder]!['maps'][mapName]['layers'][layerName] =
          !_folders[folder]!['maps'][mapName]['layers'][layerName];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text("Sauvegarder (Legacy)", style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                "Outil legacy désactivé.\nUtilise le Wizard Circuit (MarketMap).",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateCircuitAssistantPage()),
                ),
                child: const Text("Ouvrir le Wizard Circuit"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final String folderName;
  final Map<String, dynamic> folderData;
  final bool isExpanded;
  final List<Map<String, dynamic>> layers;
  final VoidCallback onToggleExpand;
  final VoidCallback onDelete;
  final Function(String) onToggleMap;
  final Function(String, String) onToggleLayer;
  final Function(String) onExpandMap;
  final String? expandedMap;

  const _FolderCard({
    required this.folderName,
    required this.folderData,
    required this.isExpanded,
    required this.layers,
    required this.onToggleExpand,
    required this.onDelete,
    required this.onToggleMap,
    required this.onToggleLayer,
    required this.onExpandMap,
    required this.expandedMap,
  });

  @override
  Widget build(BuildContext context) {
    final mapCount = (folderData['maps'] as Map).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggleExpand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.folder,
                    size: 24,
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folderName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2A37),
                          ),
                        ),
                        Text(
                          "$mapCount circuit${mapCount != 1 ? 's' : ''}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(
              height: 1,
              color: Colors.grey.shade100,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: (folderData['maps'] as Map).entries
                    .map((mapEntry) => _MapCard(
                          mapName: mapEntry.key,
                          mapData: mapEntry.value,
                          layers: layers,
                          isExpanded: expandedMap == mapEntry.key,
                          onToggleExpand: () => onExpandMap(mapEntry.key),
                          onToggleMap: () => onToggleMap(mapEntry.key),
                          onToggleLayer: (layerName) => onToggleLayer(mapEntry.key, layerName),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final String mapName;
  final Map<String, dynamic> mapData;
  final List<Map<String, dynamic>> layers;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleMap;
  final Function(String) onToggleLayer;

  const _MapCard({
    required this.mapName,
    required this.mapData,
    required this.layers,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onToggleMap,
    required this.onToggleLayer,
  });

  @override
  Widget build(BuildContext context) {
    final isMapEnabled = mapData['enabled'] as bool;
    final mapLayers = mapData['layers'] as Map<String, bool>;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isMapEnabled ? const Color(0xFF1A73E8).withAlpha(15) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMapEnabled ? const Color(0xFF1A73E8).withAlpha(77) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggleExpand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: isMapEnabled,
                      onChanged: (_) => onToggleMap(),
                      activeColor: const Color(0xFF1A73E8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mapName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isMapEnabled
                            ? const Color(0xFF1F2A37)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  if (mapLayers.isNotEmpty)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.grey,
                    ),
                ],
              ),
            ),
          ),
          if (isExpanded && isMapEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Couches",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: layers
                        .map((layer) => _LayerToggle(
                              layerName: layer['name'],
                              icon: layer['icon'],
                              color: layer['color'],
                              isEnabled: mapLayers[layer['name']] ?? false,
                              onToggle: () => onToggleLayer(layer['name']),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  final String layerName;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final VoidCallback onToggle;

  const _LayerToggle({
    required this.layerName,
    required this.icon,
    required this.color,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: isEnabled ? color.withAlpha(38) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEnabled ? color.withAlpha(128) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isEnabled ? color : Colors.grey.shade400,
            ),
            const SizedBox(height: 6),
            Text(
              layerName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isEnabled ? color : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateFolderDialog extends StatefulWidget {
  final Function(String) onSave;

  const _CreateFolderDialog({required this.onSave});

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Nouveau dossier"),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: "Nom du dossier",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        TextButton(
          onPressed: _controller.text.isEmpty
              ? null
              : () => widget.onSave(_controller.text),
          child: const Text("Créer"),
        ),
      ],
    );
  }
}
