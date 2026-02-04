import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

import 'package:flutter/material.dart';

/// Widget qui intègre Mapbox GL JS via HtmlElementView pour Flutter Web
/// 
/// Utilise le bridge JavaScript (mapbox_bridge.js) pour initialiser
/// et contrôler la carte Mapbox.
class WebMapboxGLMap extends StatefulWidget {
  /// Token d'accès Mapbox
  final String accessToken;

  /// Style de la carte (URL mapbox:// ou HTTP)
  final String style;

  /// Position initiale [lng, lat]
  final List<double> center;

  /// Niveau de zoom initial
  final double zoom;

  /// Inclinaison initiale (0-60 degrés)
  final double pitch;

  /// Rotation initiale (0-360 degrés)
  final double bearing;

  /// Activer les bâtiments 3D automatiquement
  final bool enable3DBuildings;

  /// Callback appelé quand la carte est prête
  final VoidCallback? onMapReady;

  /// Callback appelé en cas d'erreur
  final Function(String error)? onError;

  const WebMapboxGLMap({
    super.key,
    required this.accessToken,
    this.style = 'mapbox://styles/mapbox/streets-v12',
    this.center = const [-61.533, 16.241],
    this.zoom = 13.0,
    this.pitch = 45.0,
    this.bearing = 0.0,
    this.enable3DBuildings = true,
    this.onMapReady,
    this.onError,
  });

  @override
  State<WebMapboxGLMap> createState() => _WebMapboxGLMapState();
}

class _WebMapboxGLMapState extends State<WebMapboxGLMap> {
  late String _viewId;
  html.DivElement? _mapContainer;
  Timer? _resizeTimer;
  Size? _lastSize;
  bool _isMapInitialized = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'mapbox-${DateTime.now().millisecondsSinceEpoch}';
    _initializeMap();
  }

  void _initializeMap() {
    // Créer le conteneur HTML pour la carte
    _mapContainer = html.DivElement()
      ..id = _viewId
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.left = '0';

    // Enregistrer le factory pour HtmlElementView
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _mapContainer!,
    );

    // Initialiser la carte Mapbox via le bridge JS
    // On attend un peu que le DOM soit prêt
    Future.delayed(const Duration(milliseconds: 100), () {
      _initializeMapboxMap();
    });
  }

  void _initializeMapboxMap() {
    try {
      // Vérifier que window.initMapboxMap existe
      if (!_hasMapboxBridge()) {
        _handleError('Mapbox bridge non disponible. Vérifiez que mapbox_bridge.js est chargé.');
        return;
      }

      // Récupérer le token depuis --dart-define ou utiliser celui du widget
      const runtimeToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');
      final tokenToUse = runtimeToken.isNotEmpty ? runtimeToken : widget.accessToken;

      // Appeler la fonction JavaScript pour initialiser la carte
      // Signature: initMapboxMap(containerId, token, options)
      final options = {
        'style': widget.style,
        'center': widget.center,
        'zoom': widget.zoom,
        'pitch': widget.pitch,
        'bearing': widget.bearing,
        'enable3DBuildings': widget.enable3DBuildings,
      };

      // Passer le token comme 2ème paramètre
      _callJsFunction('initMapboxMap', [_viewId, tokenToUse.isEmpty ? null : tokenToUse, options]);

      // Installer le callback de ready
      _installReadyCallback();

      _isMapInitialized = true;
      debugPrint('✅ Mapbox GL Map initialisée: $_viewId');
    } catch (e) {
      _handleError('Erreur lors de l\'initialisation de Mapbox: $e');
    }
  }

  bool _hasMapboxBridge() {
    try {
      return js.context.hasProperty('initMapboxMap');
    } catch (_) {
      return false;
    }
  }

  void _callJsFunction(String functionName, List<dynamic> args) {
    try {
      if (js.context.hasProperty(functionName)) {
        js.context.callMethod(functionName, args);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de l\'appel à $functionName: $e');
    }
  }

  void _installReadyCallback() {
    // Installer un callback global pour être notifié quand la carte est prête
    js.context['onMapboxReady'] = js.JsFunction.withThis((dynamic _) {
      if (!mounted) return;
      debugPrint('✅ Mapbox GL Map prête');
      widget.onMapReady?.call();
    });
  }

  void _handleError(String error) {
    debugPrint('❌ $error');
    widget.onError?.call(error);
  }

  void _handleResize(Size size) {
    if (_lastSize == size || !_isMapInitialized) return;
    _lastSize = size;

    // Debounce pour éviter trop d'appels
    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 150), () {
      try {
        _callJsFunction('resizeMap', []);
        debugPrint('🔄 Carte redimensionnée: ${size.width.toInt()}x${size.height.toInt()}');
      } catch (e) {
        debugPrint('⚠️ Erreur resize: $e');
      }
    });
  }

  /// Met à jour la position du marqueur utilisateur
  void updateUserMarker(double lng, double lat) {
    if (!_isMapInitialized) return;
    _callJsFunction('updateUserMarker', [lng, lat]);
  }

  /// Centre la carte sur une position
  void flyTo(double lng, double lat, [double? zoom]) {
    if (!_isMapInitialized) return;
    _callJsFunction('flyToPosition', [lng, lat, zoom ?? widget.zoom]);
  }

  /// Change le style de la carte
  void setStyle(String styleUrl) {
    if (!_isMapInitialized) return;
    _callJsFunction('setMapStyle', [styleUrl]);
  }

  /// Ajuste la vue sur des bounds
  void fitBounds(List<List<double>> bounds) {
    if (!_isMapInitialized) return;
    _callJsFunction('fitBounds', [bounds]);
  }

  /// Ajoute un marqueur
  void addMarker(String id, double lng, double lat, {Map<String, dynamic>? options}) {
    if (!_isMapInitialized) return;
    _callJsFunction('addMarker', [id, lng, lat, options ?? {}]);
  }

  /// Supprime un marqueur
  void removeMarker(String id) {
    if (!_isMapInitialized) return;
    _callJsFunction('removeMarker', [id]);
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    
    // Nettoyer le callback
    js.context['onMapboxReady'] = null;

    // Détruire la carte Mapbox
    if (_isMapInitialized) {
      try {
        _callJsFunction('destroyMap', []);
      } catch (e) {
        debugPrint('⚠️ Erreur lors de la destruction de la carte: $e');
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        
        // Planifier le resize après le build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleResize(size);
        });

        return Container(
          color: const Color(0xFF1A1A2E), // Fond pendant le chargement
          child: HtmlElementView(
            key: ValueKey(_viewId),
            viewType: _viewId,
          ),
        );
      },
    );
  }
}
