import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

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
  web.HTMLDivElement? _mapContainer;
  Timer? _resizeTimer;
  Size? _lastSize;
  bool _isMapInitialized = false;
  StreamSubscription<web.MessageEvent>? _messageSub;
  bool _didNotifyReady = false;

  final Map<String, _MarkerSpec> _markers = <String, _MarkerSpec>{};
  _MarkerSpec? _userMarker;

  @override
  void initState() {
    super.initState();
    _viewId = 'mapbox-${DateTime.now().millisecondsSinceEpoch}';
    _initializeMap();

    _messageSub = web.window.onMessage.listen((evt) {
      final raw = evt.data;
      final data = raw?.toString();
      if (data == null || data.isEmpty) return;
      try {
        final decoded = jsonDecode(data);
        if (decoded is! Map) return;
        if (decoded['containerId'] != _viewId) return;
        if (decoded['type'] == 'MASLIVE_MAP_READY') {
          if (_didNotifyReady) return;
          _didNotifyReady = true;
          if (!mounted) return;
          widget.onMapReady?.call();
        }
      } catch (_) {
        // ignore
      }
    });
  }

  void _initializeMap() {
    // Créer le conteneur HTML pour la carte
    _mapContainer = web.document.createElement('div') as web.HTMLDivElement
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
      // Récupérer le token depuis --dart-define ou utiliser celui du widget
      const runtimeToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');
      final tokenToUse = runtimeToken.isNotEmpty ? runtimeToken : widget.accessToken;

      if (tokenToUse.trim().isEmpty) {
        _handleError('Token Mapbox manquant. Configure MAPBOX_ACCESS_TOKEN (ou MAPBOX_TOKEN legacy).');
        return;
      }

      final optionsJson = jsonEncode({
        'style': widget.style,
        'center': widget.center,
        'zoom': widget.zoom,
        'pitch': widget.pitch,
        'bearing': widget.bearing,
        'enable3DBuildings': widget.enable3DBuildings,
      });

      final ok = _mbInit(_viewId, tokenToUse, optionsJson);
      if (!ok) {
        _handleError('Impossible d\'initialiser Mapbox (MasliveMapboxV2.init a échoué).');
        return;
      }

      _isMapInitialized = true;
      debugPrint('✅ Mapbox GL Map initialisée: $_viewId');
    } catch (e) {
      _handleError('Erreur lors de l\'initialisation de Mapbox: $e');
    }
  }

  void _syncMarkers() {
    if (!_isMapInitialized) return;
    try {
      final all = <Map<String, Object?>>[];

      for (final entry in _markers.entries) {
        all.add({
          'id': entry.key,
          'lng': entry.value.lng,
          'lat': entry.value.lat,
          'size': entry.value.size,
          'color': entry.value.colorHex,
        });
      }

      final user = _userMarker;
      if (user != null) {
        all.add({
          'id': 'user',
          'lng': user.lng,
          'lat': user.lat,
          'size': user.size,
          'color': user.colorHex,
        });
      }

      _mbSetMarkers(_viewId, jsonEncode(all));
    } catch (e) {
      debugPrint('⚠️ syncMarkers error: $e');
    }
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
      debugPrint('🔄 Carte redimensionnée: ${size.width.toInt()}x${size.height.toInt()}');
    });
  }

  /// Met à jour la position du marqueur utilisateur
  void updateUserMarker(double lng, double lat) {
    if (!_isMapInitialized) return;
    _userMarker = _MarkerSpec(lng: lng, lat: lat, size: 1.0, colorHex: '#4285F4');
    _syncMarkers();
  }

  /// Centre la carte sur une position
  void flyTo(double lng, double lat, [double? zoom]) {
    if (!_isMapInitialized) return;
    _mbMoveTo(_viewId, lng, lat, zoom ?? widget.zoom, true);
  }

  /// Change le style de la carte
  void setStyle(String styleUrl) {
    if (!_isMapInitialized) return;
    _mbSetStyle(_viewId, styleUrl);
  }

  /// Ajuste la vue sur des bounds
  void fitBounds(List<List<double>> bounds) {
    if (!_isMapInitialized) return;
    // Fallback simple: centre sur le milieu des bounds (sans calcul de zoom).
    if (bounds.length != 2) return;
    final a = bounds[0];
    final b = bounds[1];
    if (a.length < 2 || b.length < 2) return;
    final midLng = (a[0] + b[0]) / 2.0;
    final midLat = (a[1] + b[1]) / 2.0;
    _mbMoveTo(_viewId, midLng, midLat, widget.zoom, true);
  }

  /// Ajoute un marqueur
  void addMarker(String id, double lng, double lat, {Map<String, dynamic>? options}) {
    if (!_isMapInitialized) return;
    final size = (options?['size'] is num) ? (options!['size'] as num).toDouble() : 1.0;
    final colorHex = (options?['color'] is String) ? options!['color'] as String : '#FF0000';
    _markers[id] = _MarkerSpec(lng: lng, lat: lat, size: size, colorHex: colorHex);
    _syncMarkers();
  }

  /// Supprime un marqueur
  void removeMarker(String id) {
    if (!_isMapInitialized) return;
    _markers.remove(id);
    _syncMarkers();
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    _messageSub?.cancel();
    
    // Détruire la carte Mapbox
    if (_isMapInitialized) {
      try {
        _mbDestroy(_viewId);
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

class _MarkerSpec {
  final double lng;
  final double lat;
  final double size;
  final String colorHex;

  const _MarkerSpec({
    required this.lng,
    required this.lat,
    required this.size,
    required this.colorHex,
  });
}

@JS('MasliveMapboxV2.init')
external bool _mbInit(String containerId, String token, String optionsJson);

@JS('MasliveMapboxV2.moveTo')
external void _mbMoveTo(String containerId, double lng, double lat, double zoom, bool animate);

@JS('MasliveMapboxV2.setStyle')
external void _mbSetStyle(String containerId, String styleUrl);

@JS('MasliveMapboxV2.setMarkers')
external void _mbSetMarkers(String containerId, String markersJson);

@JS('MasliveMapboxV2.destroy')
external void _mbDestroy(String containerId);
