// Exemple d'intégration du service de transparence des immeubles 3D
// dans home_map_page_3d.dart ou toute autre page avec carte Mapbox

import 'package:flutter/material.dart';
import 'package:masslive/route_style_pro/models/route_style_config.dart';
import 'package:masslive/route_style_pro/services/map_buildings_style_service_web.dart'
    if (dart.library.io) 'package:masslive/route_style_pro/services/map_buildings_style_service_native.dart';

// ========================================================================
// EXEMPLE COMPLET : Intégration dans une page existante
// ========================================================================

class ExampleMapPageWithBuildingsOpacity extends StatefulWidget {
  final String? circuitId;
  
  const ExampleMapPageWithBuildingsOpacity({
    Key? key,
    this.circuitId,
  }) : super(key: key);

  @override
  State<ExampleMapPageWithBuildingsOpacity> createState() =>
      _ExampleMapPageWithBuildingsOpacityState();
}

class _ExampleMapPageWithBuildingsOpacityState
    extends State<ExampleMapPageWithBuildingsOpacity> {
  
  // 1️⃣ Déclaration du service
  late final MapBuildingsStyleService _buildingsService;
  
  // 2️⃣ Référence à la carte Mapbox (dépend de votre implémentation)
  // MapboxMap? _mapboxMap; // Pour natif
  
  // 3️⃣ Configuration actuelle du style
  RouteStyleConfig? _currentStyleConfig;
  
  // Autres variables de votre page...
  bool _mapLoaded = false;
  
  @override
  void initState() {
    super.initState();
    
    // 4️⃣ Initialiser le service (web ou natif selon plateforme)
    _buildingsService = MapBuildingsStyleServiceWeb(); // ou Native
    
    // 5️⃣ Charger le style depuis Firestore
    _loadStyleConfig();
  }
  
  // ========================================================================
  // CHARGEMENT DU STYLE DEPUIS FIRESTORE
  // ========================================================================
  
  Future<void> _loadStyleConfig() async {
    if (widget.circuitId == null) return;
    
    try {
      // Charger depuis Firestore
      final doc = await FirebaseFirestore.instance
          .collection('circuits')
          .doc(widget.circuitId)
          .get();
      
      if (!doc.exists) return;
      
      final data = doc.data();
      if (data == null) return;
      
      // Parser le routeStylePro
      final styleProJson = data['routeStylePro'];
      if (styleProJson is Map) {
        setState(() {
          _currentStyleConfig = RouteStyleConfig.fromJson(
            Map<String, dynamic>.from(styleProJson),
          );
        });
        
        // Si la carte est déjà chargée, appliquer immédiatement
        if (_mapLoaded) {
          await _applyBuildingsStyle();
        }
      }
    } catch (e) {
      debugPrint('[BuildingsOpacity] Error loading config: $e');
    }
  }
  
  // ========================================================================
  // CALLBACKS CARTE MAPBOX
  // ========================================================================
  
  /// Appelé quand la carte est créée
  Future<void> _onMapCreated(MapboxMap map) async {
    // (Code existant de votre page...)
    
    // 6️⃣ Natif uniquement : Injecter l'instance MapboxMap
    // if (_buildingsService is MapBuildingsStyleServiceNative) {
    //   (_buildingsService as MapBuildingsStyleServiceNative).setMapInstance(map);
    // }
    
    // Permettre l'application du style
    setState(() {
      _mapLoaded = true;
    });
  }
  
  /// Appelé quand le style Mapbox est chargé/changé
  Future<void> _onStyleLoaded() async {
    // (Code existant de votre page...)
    
    // 7️⃣ Invalider le cache et réappliquer le style
    _buildingsService.invalidateCache();
    
    // Réappliquer l'opacité des bâtiments
    await _applyBuildingsStyle();
    
    debugPrint('[BuildingsOpacity] Style reloaded, opacity reapplied');
  }
  
  // ========================================================================
  // APPLICATION DE LA TRANSPARENCE
  // ========================================================================
  
  /// Appliquer l'opacité et la visibilité des bâtiments 3D
  Future<void> _applyBuildingsStyle() async {
    if (!_mapLoaded) {
      debugPrint('[BuildingsOpacity] Map not loaded yet, skipping');
      return;
    }
    
    if (_currentStyleConfig == null) {
      debugPrint('[BuildingsOpacity] No style config loaded, using defaults');
      _currentStyleConfig = RouteStyleConfig(); // Valeurs par défaut
    }
    
    final config = _currentStyleConfig!;
    
    try {
      // 8️⃣ Activer/désactiver les bâtiments 3D
      await _buildingsService.setBuildingsEnabled(config.buildings3dEnabled);
      debugPrint('[BuildingsOpacity] Buildings enabled: ${config.buildings3dEnabled}');
      
      // 9️⃣ Appliquer l'opacité si activé
      if (config.buildings3dEnabled) {
        final success = await _buildingsService.setBuildingsOpacity(
          config.buildingOpacity,
        );
        
        if (success) {
          debugPrint('[BuildingsOpacity] ✅ Applied opacity: ${config.buildingOpacity}');
        } else {
          debugPrint('[BuildingsOpacity] ⚠️ Could not apply opacity (layer not found?)');
        }
      }
    } catch (e, stack) {
      debugPrint('[BuildingsOpacity] ❌ Error applying style: $e');
      debugPrint(stack.toString());
    }
  }
  
  // ========================================================================
  // CHANGEMENT DE STYLE VIA L'UI (ex: depuis un panneau de contrôles)
  // ========================================================================
  
  /// Appelé quand l'utilisateur change l'opacité via un slider
  Future<void> _onStyleConfigChanged(RouteStyleConfig newConfig) async {
    setState(() {
      _currentStyleConfig = newConfig;
    });
    
    // 🔟 Appliquer immédiatement les changements
    await _applyBuildingsStyle();
    
    // Sauvegarder dans Firestore (optionnel)
    if (widget.circuitId != null) {
      await _saveStyleConfig(newConfig);
    }
  }
  
  /// Sauvegarder le style dans Firestore
  Future<void> _saveStyleConfig(RouteStyleConfig config) async {
    if (widget.circuitId == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('circuits')
          .doc(widget.circuitId)
          .update({
        'routeStylePro': config.toJson(),
      });
      
      debugPrint('[BuildingsOpacity] Config saved to Firestore');
    } catch (e) {
      debugPrint('[BuildingsOpacity] Error saving config: $e');
    }
  }
  
  // ========================================================================
  // BUILD UI
  // ========================================================================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte avec Transparence 3D')),
      body: Stack(
        children: [
          // Votre carte Mapbox existante
          _buildMapWidget(),
          
          // Panneau de contrôles (exemple)
          Positioned(
            top: 16,
            right: 16,
            child: _buildControlsPanel(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapWidget() {
    // Retournez votre widget MapboxMap existant
    return Container(
      color: Colors.grey[300],
      child: const Center(child: Text('Carte Mapbox ici')),
    );
  }
  
  Widget _buildControlsPanel() {
    if (_currentStyleConfig == null) return const SizedBox.shrink();
    
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Immeubles 3D',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            
            // Switch Activer/Désactiver
            SwitchListTile(
              title: const Text('Afficher les immeubles'),
              value: _currentStyleConfig!.buildings3dEnabled,
              onChanged: (enabled) {
                _onStyleConfigChanged(
                  _currentStyleConfig!.copyWith(buildings3dEnabled: enabled),
                );
              },
            ),
            
            // Slider Opacité
            if (_currentStyleConfig!.buildings3dEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'Opacité: ${(_currentStyleConfig!.buildingOpacity * 100).toInt()}%',
              ),
              Slider(
                value: _currentStyleConfig!.buildingOpacity,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: '${(_currentStyleConfig!.buildingOpacity * 100).toInt()}%',
                onChanged: (opacity) {
                  _onStyleConfigChanged(
                    _currentStyleConfig!.copyWith(buildingOpacity: opacity),
                  );
                },
              ),
              
              // Presets rapides
              Wrap(
                spacing: 8,
                children: [
                  _buildPresetChip('Ghost', 0.2),
                  _buildPresetChip('Léger', 0.35),
                  _buildPresetChip('Moyen', 0.55),
                  _buildPresetChip('Confort', 0.7),
                  _buildPresetChip('Opaque', 1.0),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPresetChip(String label, double value) {
    final isSelected = (_currentStyleConfig!.buildingOpacity - value).abs() < 0.05;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        _onStyleConfigChanged(
          _currentStyleConfig!.copyWith(buildingOpacity: value),
        );
      },
    );
  }
}

// ========================================================================
// UTILISATION DANS UNE PAGE EXISTANTE (home_map_page_3d.dart)
// ========================================================================

/*

ÉTAPES POUR INTÉGRER DANS VOTRE PAGE EXISTANTE :

1️⃣ Ajouter les imports en haut de votre fichier :

   import 'package:masslive/route_style_pro/services/map_buildings_style_service_web.dart'
       if (dart.library.io) 'package:masslive/route_style_pro/services/map_buildings_style_service_native.dart';

2️⃣ Dans votre State, déclarer :

   late final MapBuildingsStyleService _buildingsService;
   RouteStyleConfig? _styleConfig;

3️⃣ Dans initState() :

   @override
   void initState() {
     super.initState();
     _buildingsService = MapBuildingsStyleServiceWeb(); // ou Native
     _loadStyleFromFirestore();
   }

4️⃣ Dans _onMapCreated (natif uniquement) :

   void _onMapCreated(MapboxMap map) {
     // Votre code existant...
     
     if (_buildingsService is MapBuildingsStyleServiceNative) {
       (_buildingsService as MapBuildingsStyleServiceNative).setMapInstance(map);
     }
   }

5️⃣ Dans _onStyleLoaded :

   void _onStyleLoaded() {
     // Votre code existant...
     
     _buildingsService.invalidateCache();
     _applyBuildingsStyleFromConfig();
   }

6️⃣ Créer la méthode d'application :

   Future<void> _applyBuildingsStyleFromConfig() async {
     if (_styleConfig == null) return;
     
     await _buildingsService.setBuildingsEnabled(_styleConfig!.buildings3dEnabled);
     if (_styleConfig!.buildings3dEnabled) {
       await _buildingsService.setBuildingsOpacity(_styleConfig!.buildingOpacity);
     }
   }

7️⃣ Charger depuis Firestore :

   Future<void> _loadStyleFromFirestore() async {
     final doc = await FirebaseFirestore.instance
         .collection('circuits')
         .doc(widget.circuitId)
         .get();
     
     if (doc.exists) {
       final data = doc.data();
       final styleProJson = data?['routeStylePro'];
       if (styleProJson is Map) {
         setState(() {
           _styleConfig = RouteStyleConfig.fromJson(
             Map<String, dynamic>.from(styleProJson),
           );
         });
         await _applyBuildingsStyleFromConfig();
       }
     }
   }

8️⃣ (Optionnel) Ajouter un panneau de contrôles UI :

   Utilisez le widget BuildingOpacityControl dans votre interface :
   
   import 'package:masslive/route_style_pro/ui/widgets/building_opacity_control.dart';
   
   // Dans votre build :
   BuildingOpacityControl(
     config: _styleConfig ?? RouteStyleConfig(),
     onChanged: (newConfig) {
       setState(() => _styleConfig = newConfig);
       _applyBuildingsStyleFromConfig();
       _saveToFirestore(newConfig);
     },
   )

9️⃣ C'est fini ! Testez :
   - Changez l'opacité → Les bâtiments deviennent transparents
   - Changez le style Mapbox → L'opacité est réappliquée
   - Rechargez la page → L'opacité sauvegardée est restaurée

*/

// ========================================================================
// EXEMPLE MINIMALISTE (copier-coller rapide)
// ========================================================================

class MinimalBuildingsOpacityExample extends StatefulWidget {
  const MinimalBuildingsOpacityExample({Key? key}) : super(key: key);
  @override
  State<MinimalBuildingsOpacityExample> createState() => _MinimalBuildingsOpacityExampleState();
}

class _MinimalBuildingsOpacityExampleState extends State<MinimalBuildingsOpacityExample> {
  late final MapBuildingsStyleService service;
  
  @override
  void initState() {
    super.initState();
    service = MapBuildingsStyleServiceWeb();
  }
  
  Future<void> setOpacity(double opacity) async {
    await service.setBuildingsOpacity(opacity);
  }
  
  @override
  Widget build(BuildContext context) {
    return Slider(
      value: 0.5,
      onChanged: setOpacity,
    );
  }
}
