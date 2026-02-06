import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide LocationSettings;
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:geolocator/geolocator.dart'
    as geo
    show Position, LocationSettings;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/gradient_icon_button.dart';
import '../ui/widgets/maslive_card.dart';
import '../ui/widgets/maslive_profile_icon.dart';
import '../services/auth_service.dart';
import '../services/geolocation_service.dart';
import '../services/language_service.dart';
import '../services/mapbox_token_service.dart';
import '../services/market_map_service.dart';
import '../models/market_poi.dart';
import '../ui/widgets/marketmap_poi_selector_sheet.dart';
import '../l10n/app_localizations.dart' as l10n;
import 'splash_wrapper_page.dart' show mapReadyNotifier;

// Menu vertical: modes/actions (filtrage POIs)
enum _MapAction { visiter, food, assistance, parking, wc }

class HomeMapPage3D extends StatefulWidget {
  const HomeMapPage3D({super.key});

  @override
  State<HomeMapPage3D> createState() => _HomeMapPage3DState();
}

class _HomeMapPage3DState extends State<HomeMapPage3D>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ========== CONSTANTES ==========
  static const Duration _resizeDebounceDelay = Duration(milliseconds: 80);
  static const Duration _menuAnimationDuration = Duration(milliseconds: 300);
  static const Duration _menuOpenDelay = Duration(seconds: 1);
  static const Duration _mapReadyDelay = Duration(milliseconds: 300);
  static const Duration _navCloseDelay = Duration(milliseconds: 1500);
  static const int _trackingIntervalSeconds = 15;
  static const int _gpsDistanceFilter = 8;
  static const Duration _gpsTimeout = Duration(seconds: 8);
  static const double _userMarkerIconSize = 1.5;
  static const Duration _cameraAnimationDuration = Duration(milliseconds: 800);
  static const double _defaultZoom = 13.0;
  static const double _userZoom = 15.5;
  static const double _defaultPitch = 45.0;
  static const double _minZoom3dBuildings = 14.5;
  // Offset vertical du menu d'actions pour ne pas chevaucher la boussole
  static const double _actionsMenuTopOffset = 160;

  // ========== ÉTAT UI ==========
  bool _showActionsMenu = false;
  late AnimationController _menuAnimController;
  late Animation<Offset> _menuSlideAnimation;
  _MapAction? _selectedAction;

  // ========== CARTE & GÉOLOCALISATION ==========
  MapboxMap? _mapboxMap;
  final GeolocationService _geo = GeolocationService.instance;

  // Fix universel rebuild + resize natif (iOS/Android/Web)
  int _mapTick = 0;
  bool _mapCanBeCreated = false;
  ui.Size? _lastSize;
  Timer? _debounce;

  StreamSubscription<geo.Position>? _positionSub;
  Position? _userPos; // Mapbox Position (lng, lat)
  bool _followUser = true;
  bool _requestingGps = false;
  bool _isTracking = false;
  bool _isMapReady = false;
  bool _isGpsReady = false;

  String _runtimeMapboxToken = '';
  // ignore: unused_field
  String? _userGroupId;
  // ignore: unused_field
  bool _isSuperAdmin = false;

  static final Position _fallbackCenter = Position(-61.533, 16.241);

  // Annotations managers
  PointAnnotationManager? _userAnnotationManager;
  PointAnnotationManager? _placesAnnotationManager;
  // ignore: unused_field
  PointAnnotationManager? _groupsAnnotationManager;
  // ignore: unused_field
  PolylineAnnotationManager? _circuitsAnnotationManager;

  // MarketMap POIs (wiring wizard)
  final MarketMapService _marketMapService = MarketMapService();
  MarketMapPoiSelection _marketPoiSelection =
      const MarketMapPoiSelection.disabled();
  StreamSubscription? _marketPoisSub;
  List<MarketPoi> _marketPois = const <MarketPoi>[];

  String get _effectiveMapboxToken => _runtimeMapboxToken.isNotEmpty
      ? _runtimeMapboxToken
      : MapboxTokenService.getTokenSync();

  bool get _useMapboxTiles => _effectiveMapboxToken.isNotEmpty;

  @override
  void initState() {
    super.initState();

    // Observer pour détecter les changements de lifecycle et de métriques (resize, rotation)
    WidgetsBinding.instance.addObserver(this);

    // Initialisation du token Mapbox (peut être vide au démarrage)
    _initMapboxToken();

    // Synchroniser l'état de tracking avec le service
    _isTracking = _geo.isTracking;

    // Configuration de l'animation du menu latéral
    _menuAnimController = AnimationController(
      duration: _menuAnimationDuration,
      vsync: this,
    )..value = 0.0;
    _menuSlideAnimation =
        Tween<Offset>(begin: const Offset(1.2, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _menuAnimController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    // Chargement asynchrone des données essentielles
    _bootstrapLocation(); // Permissions GPS + position initiale
    _loadUserGroupId(); // Données utilisateur Firebase
    _loadRuntimeMapboxToken(); // Token Mapbox dynamique
  }

  void _initMapboxToken() {
    if (_effectiveMapboxToken.isEmpty) {
      setState(() {
        _runtimeMapboxToken = '';
      });
      return;
    }
    MapboxOptions.setAccessToken(_effectiveMapboxToken);
  }

  Future<void> _loadRuntimeMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (!mounted) return;
      setState(() {
        _runtimeMapboxToken = info.token;
        if (_runtimeMapboxToken.isNotEmpty) {
          MapboxOptions.setAccessToken(_runtimeMapboxToken);
        }
      });
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _marketPoisSub?.cancel();
    _menuAnimController.dispose();
    super.dispose();
  }

  Color _poiColorForType(String? type) {
    switch (type) {
      case 'food':
        return const Color(0xFFFF9800);
      case 'visit':
        return const Color(0xFF9B6BFF);
      case 'wc':
        return const Color(0xFF2196F3);
      case 'parking':
        return const Color(0xFF4CAF50);
      case 'assistance':
        return const Color(0xFFFFC107);
      case 'market':
      default:
        return const Color(0xFFE91E63);
    }
  }

  Future<void> _openMarketPoiSelector() async {
    final selection = await showMarketMapPoiSelectorSheet(
      context,
      service: _marketMapService,
      initial: _marketPoiSelection,
    );
    if (selection == null) return;
    if (!mounted) return;

    setState(() {
      _marketPoiSelection = selection;
    });

    await _applyMarketPoiSelection(selection);
  }

  Future<void> _applyMarketPoiSelection(MarketMapPoiSelection selection) async {
    await _marketPoisSub?.cancel();
    _marketPoisSub = null;

    if (!selection.enabled ||
        selection.country == null ||
        selection.event == null ||
        selection.circuit == null) {
      if (!mounted) return;
      setState(() {
        _marketPois = const <MarketPoi>[];
      });
      await _renderMarketPoiMarkers();
      return;
    }

    final circuit = selection.circuit!;
    final styleUrl = circuit.styleUrl?.trim();
    if (styleUrl != null && styleUrl.isNotEmpty && _mapboxMap != null) {
      try {
        await _mapboxMap!.style.setStyleURI(styleUrl);
      } catch (e) {
        debugPrint('⚠️ Erreur chargement style circuit: $e');
      }
    }
    final center = circuit.center;
    final lng = (center['lng'] ?? _fallbackCenter.lng).toDouble();
    final lat = (center['lat'] ?? _fallbackCenter.lat).toDouble();
    await _moveCameraTo(lng: lng, lat: lat, zoom: circuit.initialZoom);

    _marketPoisSub = _marketMapService
        .watchVisiblePois(
          countryId: selection.country!.id,
          eventId: selection.event!.id,
          circuitId: selection.circuit!.id,
          layerIds: selection.layerIds,
        )
        .listen((pois) async {
          if (!mounted) return;
          setState(() {
            _marketPois = pois;
          });
          await _renderMarketPoiMarkers();
        });
  }

  Future<void> _moveCameraTo({
    required double lng,
    required double lat,
    required double zoom,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      final camera = CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      );
      await map.flyTo(
        camera,
        MapAnimationOptions(duration: _cameraAnimationDuration.inMilliseconds),
      );
    } catch (e) {
      debugPrint('⚠️ moveCameraTo error: $e');
    }
  }

  Future<void> _renderMarketPoiMarkers() async {
    final manager = _placesAnnotationManager;
    if (manager == null) return;

    try {
      await manager.deleteAll();
    } catch (_) {
      // ignore
    }

    if (!_marketPoiSelection.enabled) return;

    final filterType = _actionToPoiType(_selectedAction);
    for (final p in _marketPois.where(
      (poi) => filterType == null || poi.type == filterType,
    )) {
      if (p.lat == 0.0 && p.lng == 0.0) continue;
      try {
        final opt = PointAnnotationOptions(
          geometry: Point(coordinates: Position(p.lng, p.lat)),
          iconImage: 'marker-15',
          iconSize: 1.2,
          iconColor: _poiColorForType(p.type).toARGB32(),
          textField: p.name,
          textSize: 12.0,
          textOffset: const [0.0, 1.2],
          textColor: Colors.black.value,
          textHaloColor: Colors.white.value,
          textHaloWidth: 1.0,
        );
        await manager.create(opt);
      } catch (_) {
        // ignore
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _bootstrapLocation();
    }
  }

  @override
  void didChangeMetrics() {
    // Détecte : rotation, split-view, resize fenêtre, clavier virtuel
    super.didChangeMetrics();

    // Incrémente le tick pour forcer un rebuild de la carte via ValueKey
    // Protégé par mounted pour éviter les setState après dispose
    if (mounted) {
      try {
        setState(() => _mapTick++);
      } catch (e) {
        debugPrint('⚠️ Erreur didChangeMetrics: $e');
      }
    }
  }

  /// Planifie un resize de la carte avec debounce pour éviter les rebuilds excessifs.
  ///
  /// Cette méthode est appelée par LayoutBuilder à chaque changement de contraintes.
  /// Le debounce évite de rebuilder la carte 10+ fois pendant une animation de resize.
  ///
  /// **Pourquoi c'est nécessaire :** Le SDK Mapbox natif ne gère pas automatiquement
  /// le resize via Flutter. On force un rebuild avec une nouvelle ValueKey.
  void _scheduleResize(ui.Size size) {
    // Tant que la taille n'est pas exploitable, on ne crée pas la carte.
    if (!size.width.isFinite || !size.height.isFinite) return;
    if (size.width <= 0 || size.height <= 0) return;

    // Ignorer si la taille n'a pas changé (optimisation)
    if (_lastSize == size) return;
    _lastSize = size;

    // Annuler le timer précédent (debounce)
    _debounce?.cancel();

    // Attendre que le resize soit stabilisé avant de rebuilder
    _debounce = Timer(_resizeDebounceDelay, () {
      if (!mounted) return; // Sécurité supplémentaire

      try {
        // 1) Autoriser la création de la carte seulement une fois que les contraintes
        // sont stabilisées (fix “premier layout” : carte initialisée trop tôt).
        // 2) Incrémenter le tick force Flutter à recréer le MapWidget avec une nouvelle Key.
        setState(() {
          _mapCanBeCreated = true;
          _mapTick++;
        });
        debugPrint(
          '✅ Map rebuild: ${size.width.toInt()}x${size.height.toInt()} (tick: $_mapTick)',
        );
      } catch (e) {
        debugPrint('⚠️ Erreur _scheduleResize: $e');
      }
    });
  }

  /// Initialise la géolocalisation au démarrage de la page.
  ///
  /// 1. Vérifie les permissions GPS
  /// 2. Récupère la position initiale
  /// 3. Met à jour le marqueur utilisateur
  /// 4. Démarre le stream de positions
  Future<void> _bootstrapLocation() async {
    final ok = await _ensureLocationPermission(request: true);

    if (ok) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: geo.LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: _gpsTimeout,
          ),
        );
        final p = Position(pos.longitude, pos.latitude);
        if (mounted) {
          setState(() {
            _userPos = p;
          });
          await _updateUserMarker();
        }
      } on TimeoutException catch (e) {
        debugPrint('⏱️ Timeout GPS: $e');
      } catch (e) {
        debugPrint('⚠️ Erreur GPS: $e');
      }
    }

    if (mounted) {
      setState(() => _isGpsReady = true);
    } else {
      _isGpsReady = true;
    }
    _checkIfReady();

    if (!ok) return;
    _startUserPositionStream();
  }

  /// Vérifie et demande les permissions de géolocalisation.
  ///
  /// Retourne true si les permissions sont accordées, false sinon.
  Future<bool> _ensureLocationPermission({required bool request}) async {
    // Éviter les requêtes concurrentes
    if (_requestingGps) return false;
    _requestingGps = true;

    try {
      // 1. Vérifier si le service de localisation est activé
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return false;
      }

      // 2. Vérifier les permissions
      var permission = await Geolocator.checkPermission();

      // 3. Demander la permission si nécessaire et autorisé
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }

      // 4. Gérer les permissions refusées
      if (permission == LocationPermission.denied) {
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('⚠️ Erreur vérification permissions GPS: $e');
      return false;
    } finally {
      _requestingGps = false;
    }
  }

  /// Démarre le stream de mise à jour de la position utilisateur en temps réel.
  ///
  /// Le filtre de distance évite les mises à jour trop fréquentes pour de petits mouvements.
  void _startUserPositionStream() {
    _positionSub?.cancel();

    const settings = geo.LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: _gpsDistanceFilter, // Mise à jour tous les 8 mètres
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (pos) {
            final p = Position(pos.longitude, pos.latitude);
            if (!mounted) return;

            setState(() {
              _userPos = p;
              if (!_isGpsReady) {
                _isGpsReady = true;
                _checkIfReady();
              }
            });

            _updateUserMarker();

            if (_followUser) {
              _mapboxMap?.flyTo(
                CameraOptions(
                  center: Point(coordinates: p),
                  zoom: _userZoom,
                ),
                MapAnimationOptions(
                  duration: _cameraAnimationDuration.inMilliseconds,
                  startDelay: 0,
                ),
              );
            }
          },
          onError: (error) {
            debugPrint('⚠️ Erreur stream position: $error');
            if (mounted) {
              setState(() => _isGpsReady = false);
            }
          },
          cancelOnError: false, // Continue à écouter même après une erreur
        );
  }

  /// Notifie que la carte est prête après un court délai.
  ///
  /// Utilisé par splash_wrapper_page pour masquer le splash screen.
  void _checkIfReady() {
    if (_isMapReady && !mapReadyNotifier.value) {
      Future.delayed(_mapReadyDelay, () {
        if (mounted) {
          mapReadyNotifier.value = true;
        }
      });
    }
  }

  /// Met à jour le marqueur de position utilisateur sur la carte.
  ///
  /// Supprime l'ancien marqueur et crée un nouveau pour éviter les doublons.
  Future<void> _updateUserMarker() async {
    // Early returns pour optimiser les performances
    if (!mounted) return;

    final manager = _userAnnotationManager;
    final pos = _userPos;
    if (manager == null || pos == null) return;

    try {
      // Supprimer tous les marqueurs existants (évite les doublons)
      await manager.deleteAll();

      // Créer le nouveau marqueur à la position actuelle
      final options = PointAnnotationOptions(
        geometry: Point(coordinates: pos),
        iconImage: 'user-location-icon',
        iconSize: _userMarkerIconSize,
      );

      await manager.create(options);
    } catch (e) {
      debugPrint('⚠️ Erreur update user marker: $e');
    }
  }

  /// Ajoute les bâtiments 3D à la carte pour un effet de profondeur.
  ///
  /// Les bâtiments apparaissent uniquement au-delà du zoom 14.5 pour optimiser les performances.
  Future<void> _add3dBuildings() async {
    if (!mounted) return;

    final map = _mapboxMap;
    if (map == null) return;

    try {
      final style = map.style;

      // Configuration du layer d'extrusion 3D
      final layer =
          FillExtrusionLayer(id: 'maslive-3d-buildings', sourceId: 'composite')
            ..sourceLayer = 'building'
            ..minZoom =
                _minZoom3dBuildings // Visible uniquement en zoom rapproché
            ..fillExtrusionColor = const Color(0xFFD1D5DB)
                .toARGB32() // Gris clair
            ..fillExtrusionOpacity =
                0.7 // Semi-transparent
            ..fillExtrusionHeight =
                20.0 // Hauteur basée sur les données OSM
            ..fillExtrusionBase = 0.0; // Pas de surélévation de base

      // Filtre : seulement les bâtiments avec propriété "extrude"
      layer.filter = const [
        '==',
        ['get', 'extrude'],
        'true',
      ];

      await style.addLayer(layer);
    } catch (e) {
      debugPrint('⚠️ Erreur ajout bâtiments 3D: $e');
    }
  }

  /// Callback appelé quand le MapWidget Mapbox est initialisé.
  ///
  /// Configure tous les aspects de la carte : gestes 3D, bâtiments, annotation managers.
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    if (!mounted) return;
    _mapboxMap = mapboxMap;

    try {
      // 1. Activer tous les gestes 3D (rotation, inclinaison, zoom)
      await mapboxMap.gestures.updateSettings(
        GesturesSettings(
          pitchEnabled: true, // Inclinaison vertical
          rotateEnabled: true, // Rotation à deux doigts
          scrollEnabled: true, // Pan/déplacement
          pinchToZoomEnabled: true, // Zoom pinch
        ),
      );

      // 2. Ajouter les bâtiments 3D au style
      await _add3dBuildings();

      // 3. Créer les annotation managers pour les marqueurs
      _userAnnotationManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      _placesAnnotationManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      _groupsAnnotationManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      _circuitsAnnotationManager = await mapboxMap.annotations
          .createPolylineAnnotationManager();
    } catch (e) {
      debugPrint('⚠️ Erreur configuration carte: $e');
    }

    // 4. Marquer la carte comme prête
    if (mounted) {
      setState(() {
        _isMapReady = true;
        _checkIfReady();
      });
    }

    // 5. Afficher le marqueur utilisateur si position disponible
    await _updateUserMarker();

    // 5b. Afficher les POIs MarketMap si un circuit est sélectionné
    await _renderMarketPoiMarkers();

    // 6. Appliquer le resize initial si LayoutBuilder a déjà capturé la taille
    if (_lastSize != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleResize(_lastSize!);
      });
    }
  }

  /// Démarre ou arrête le tracking GPS de la position utilisateur.
  ///
  /// Le tracking partage la position avec le groupe de l'utilisateur à intervalles réguliers.
  Future<void> _toggleTracking() async {
    // Arrêter le tracking si déjà actif
    if (_isTracking) {
      _geo.stopTracking();
      if (mounted) {
        setState(() => _isTracking = false);
      }
      return;
    }

    // Vérifier l'authentification
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    // Charger le profil utilisateur
    final profile = await AuthService.instance.getUserProfile(uid);
    if (!mounted) return;

    final groupId = profile?.groupId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final ok = await _geo.startTracking(
      groupId: groupId,
      intervalSeconds: _trackingIntervalSeconds,
    );
    if (!mounted) return;
    setState(() => _isTracking = ok);
  }

  Future<void> _loadUserGroupId() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final groupId = doc.data()?['groupId'] as String?;
        final role = doc.data()?['role'] as String?;
        final isAdmin = doc.data()?['isAdmin'] as bool? ?? false;

        final isSuperAdmin =
            role == 'superAdmin' ||
            role == 'superadmin' ||
            (isAdmin && (role == 'admin' || role == 'Admin'));

        if (groupId != null) {
          setState(() {
            _userGroupId = groupId;
            _isSuperAdmin = isSuperAdmin;
          });
        } else {
          setState(() => _isSuperAdmin = isSuperAdmin);
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement groupId: $e');
    }
  }

  void _cycleLanguage() {
    final langService = Get.find<LanguageService>();
    final langs = ['fr', 'en', 'es'];
    final current = langService.currentLanguageCode;
    final idx = langs.indexOf(current);
    final next = langs[(idx + 1) % langs.length];
    langService.changeLanguage(next);
    setState(() {});
  }

  void _selectAction(_MapAction action, String label) {
    setState(() => _selectedAction = action);
    _renderMarketPoiMarkers();
  }

  void _toggleActionsMenu() {
    if (_showActionsMenu) {
      _menuAnimController.reverse();
      Future.delayed(_menuAnimationDuration, () {
        if (mounted && _showActionsMenu) {
          setState(() => _showActionsMenu = false);
        }
      });
      return;
    }

    setState(() => _showActionsMenu = true);
    _menuAnimController.value = 0;
    Future.delayed(_menuOpenDelay, () {
      if (!mounted || !_showActionsMenu) return;
      _menuAnimController.forward();
    });
  }

  String? _actionToPoiType(_MapAction? action) {
    switch (action) {
      case _MapAction.visiter:
        return 'visit';
      case _MapAction.food:
        return 'food';
      case _MapAction.assistance:
        return 'assistance';
      case _MapAction.parking:
        return 'parking';
      case _MapAction.wc:
        return 'wc';
      case null:
        return null;
    }
  }

  Future<void> _showMapProjectsSelector() async {
    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      service: _marketMapService,
      initial: _marketPoiSelection.enabled ? _marketPoiSelection : null,
    );
    if (selection == null || !mounted) return;

    setState(() {
      _marketPoiSelection = selection;
    });

    await _applyMarketPoiSelection(selection);
  }

  /// Ferme automatiquement le menu de navigation après un délai.
  void _closeNavWithDelay() {
    Future.delayed(_navCloseDelay, () {
      if (mounted && _showActionsMenu) {
        _menuAnimController.reverse();
        Future.delayed(_menuAnimationDuration, () {
          if (mounted && _showActionsMenu) {
            setState(() => _showActionsMenu = false);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder capture les changements de taille du widget parent.
    // Essentiel pour détecter : resize fenêtre, rotation, split-screen, clavier
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = ui.Size(constraints.maxWidth, constraints.maxHeight);

        // PostFrameCallback garantit que le resize est appelé APRÈS
        // que le layout soit terminé, évitant les conflits avec setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduleResize(size);
        });

        return _buildContent(context, size);
      },
    );
  }

  Widget _buildContent(BuildContext context, ui.Size size) {
    if (!_useMapboxTiles) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carte 3D')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Token Mapbox requis',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Configure MAPBOX_ACCESS_TOKEN pour activer la carte 3D.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Rend le fond transparent
        statusBarIconBrightness: Brightness.dark, // Icônes noires
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced:
            false, // Désactive le filtre automatique
        systemNavigationBarColor: Colors.transparent, // Navigation transparente
        systemNavigationBarContrastEnforced:
            false, // Désactive le filtre navigation
      ),
      child: Scaffold(
        extendBody:
            true, // Permet à la carte de passer SOUS la barre de navigation
        extendBodyBehindAppBar:
            true, // IMPORTANT : la carte passera sous la barre d'état
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // Carte Mapbox 3D - Occupe tout l'écran
            Positioned.fill(
              child: RepaintBoundary(
                // Optimise les performances de rendu
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Container(
                    color:
                        Colors.black, // Couleur de fond pendant le chargement
                    child: _mapCanBeCreated
                        ? MapWidget(
                            key: ValueKey(
                              'map_${size.width.toInt()}x${size.height.toInt()}_$_mapTick',
                            ),
                            styleUri: 'mapbox://styles/mapbox/streets-v12',
                            cameraOptions: CameraOptions(
                              center: Point(
                                coordinates: _userPos ?? _fallbackCenter,
                              ),
                              zoom: _userPos != null ? _userZoom : _defaultZoom,
                              pitch: _defaultPitch,
                              bearing: 0.0,
                            ),
                            onMapCreated: _onMapCreated,
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
            ),

            // Boussole (demi-flèche rouge)
            const Positioned(top: 104, right: 14, child: _HalfRedCompass()),

            // Overlay actions menu
            if (_showActionsMenu)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _menuAnimController.reverse();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        setState(() => _showActionsMenu = false);
                      }
                    });
                  },
                  child: Align(
                    alignment: Alignment.topRight,
                    child: SlideTransition(
                      position: _menuSlideAnimation,
                      child: Container(
                        margin: const EdgeInsets.only(
                          right: 0,
                          top: _actionsMenuTopOffset,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                            bottom: Radius.circular(24),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ActionItem(
                                label: 'Carte',
                                icon: Icons.map_rounded,
                                selected: _marketPoiSelection.enabled,
                                onTap: () {
                                  _showMapProjectsSelector();
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: 'POIs',
                                icon: Icons.place_rounded,
                                selected: _marketPoiSelection.enabled,
                                onTap: () {
                                  _openMarketPoiSelector();
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: l10n.AppLocalizations.of(
                                  context,
                                )!.tracking,
                                icon: Icons.track_changes_rounded,
                                selected: _isTracking,
                                onTap: () {
                                  _toggleTracking();
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: l10n.AppLocalizations.of(context)!.visit,
                                icon: Icons.map_outlined,
                                selected: _selectedAction == _MapAction.visiter,
                                onTap: () {
                                  _selectAction(_MapAction.visiter, 'Visiter');
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: l10n.AppLocalizations.of(context)!.food,
                                icon: Icons.fastfood_rounded,
                                selected: _selectedAction == _MapAction.food,
                                onTap: () {
                                  _selectAction(_MapAction.food, 'Food');
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: l10n.AppLocalizations.of(
                                  context,
                                )!.assistance,
                                icon: Icons.shield_outlined,
                                selected:
                                    _selectedAction == _MapAction.assistance,
                                onTap: () {
                                  _selectAction(
                                    _MapAction.assistance,
                                    'Assistance',
                                  );
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: '',
                                iconWidget: Image.asset(
                                  'assets/images/icon wc parking.png',
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                ),
                                fullBleed: true,
                                showBorder: false,
                                selected: _selectedAction == _MapAction.parking,
                                onTap: () {
                                  _selectAction(_MapAction.parking, 'Parking');
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: '',
                                iconWidget: Obx(() {
                                  final lang = Get.find<LanguageService>();
                                  final flag = lang.getLanguageFlag(
                                    lang.currentLanguageCode,
                                  );
                                  return Container(
                                    color: Colors.white,
                                    alignment: Alignment.center,
                                    child: Text(
                                      flag,
                                      style: const TextStyle(
                                        fontSize: 34,
                                        height: 1,
                                      ),
                                    ),
                                  );
                                }),
                                fullBleed: true,
                                tintOnSelected: false,
                                showBorder: false,
                                selected: _selectedAction == _MapAction.wc,
                                onTap: () {
                                  _selectAction(_MapAction.wc, 'Langue');
                                  _cycleLanguage();
                                  _closeNavWithDelay();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Tracking pill
            if (_isTracking)
              Positioned(
                left: 16,
                right: 90,
                bottom: 18,
                child: _TrackingPill(
                  isTracking: _isTracking,
                  onToggle: _toggleTracking,
                ),
              ),

            // Bottom bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MasliveGradientHeader(
                height: 60,
                borderRadius: BorderRadius.zero,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                backgroundColor: Colors.transparent,
                child: Row(
                  children: [
                    StreamBuilder<User?>(
                      stream: AuthService.instance.authStateChanges,
                      builder: (context, snap) {
                        final user = snap.data;
                        final pseudo =
                            (user?.displayName ?? user?.email ?? 'Profil')
                                .trim();

                        return Tooltip(
                          message: pseudo.isEmpty ? 'Profil' : pseudo,
                          child: InkWell(
                            onTap: () {
                              if (user != null) {
                                Navigator.pushNamed(context, '/account-ui');
                              } else {
                                Navigator.pushNamed(context, '/login');
                              }
                            },
                            customBorder: const CircleBorder(),
                            child: MasliveProfileIcon(
                              size: 46,
                              badgeSizeRatio: 0.22,
                              showBadge: user != null,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    const Spacer(),
                    MasliveGradientIconButton(
                      icon: Icons.shopping_bag_rounded,
                      tooltip: l10n.AppLocalizations.of(context)!.shop,
                      onTap: () {
                        Navigator.pushNamed(context, '/shop-ui');
                      },
                    ),
                    const SizedBox(width: 10),
                    MasliveGradientIconButton(
                      icon: Icons.menu_rounded,
                      tooltip: l10n.AppLocalizations.of(context)!.menu,
                      onTap: () {
                        _toggleActionsMenu();
                      },
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
}

class _ActionItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onTap;
  final bool fullBleed;
  final bool tintOnSelected;
  final bool showBorder;

  const _ActionItem({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.selected,
    required this.onTap,
    this.fullBleed = false,
    this.tintOnSelected = true,
    this.showBorder = true,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          border: showBorder
              ? Border.all(
                  color: selected ? MasliveTheme.pink : MasliveTheme.divider,
                  width: selected ? 2.0 : 1.0,
                )
              : null,
          boxShadow: selected ? MasliveTheme.cardShadow : const [],
        ),
        child: fullBleed
            ? ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (iconWidget != null) iconWidget!,
                    if (icon != null)
                      Center(
                        child: Icon(
                          icon,
                          size: 28,
                          color: selected && tintOnSelected
                              ? MasliveTheme.pink
                              : MasliveTheme.textPrimary,
                        ),
                      ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconWidget != null)
                    IconTheme(
                      data: IconThemeData(
                        size: label.isEmpty ? 32 : 28,
                        color: selected && tintOnSelected
                            ? MasliveTheme.pink
                            : MasliveTheme.textPrimary,
                      ),
                      child: iconWidget!,
                    )
                  else
                    Icon(
                      icon,
                      size: label.isEmpty ? 32 : 28,
                      color: selected && tintOnSelected
                          ? MasliveTheme.pink
                          : MasliveTheme.textPrimary,
                    ),
                  if (label.isNotEmpty) const SizedBox(height: 4),
                  if (label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? Colors.white
                              : MasliveTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 8,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _HalfRedCompass extends StatelessWidget {
  const _HalfRedCompass();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: MasliveTheme.cardShadow,
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.navigation_rounded,
              size: 26,
              color: Color(0xFF111827),
            ),
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 26,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingPill extends StatelessWidget {
  final bool isTracking;
  final VoidCallback onToggle;

  const _TrackingPill({required this.isTracking, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return MasliveCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isTracking ? Colors.green : Colors.black).withValues(
                alpha: 0.08,
              ),
            ),
            child: Icon(
              isTracking
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
              color: isTracking ? Colors.green : MasliveTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking GPS',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  isTracking
                      ? 'Actif (${_HomeMapPage3DState._trackingIntervalSeconds}s)'
                      : 'Inactif',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MasliveTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onToggle,
            icon: Icon(isTracking ? Icons.stop_circle : Icons.play_circle),
            label: Text(isTracking ? 'Stop' : 'Start'),
          ),
        ],
      ),
    );
  }
}
