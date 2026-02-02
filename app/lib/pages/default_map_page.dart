import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../services/mapbox_token_service.dart';
import '../services/auth_service.dart';
import '../services/geolocation_service.dart';
import '../services/language_service.dart';
import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/gradient_icon_button.dart';
import '../ui/widgets/maslive_card.dart';
import '../ui/widgets/maslive_profile_icon.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';
import 'splash_wrapper_page.dart' show mapReadyNotifier;
import '../l10n/app_localizations.dart' as l10n;

// Menu vertical: modes/actions (pour refléter la sélection UI)
// Note: seul le tracking et les projets sont pleinement câblés ici.
enum _MapAction { visiter, food, assistance, parking, wc }

/// Page de carte par défaut avec Mapbox en plein écran
class DefaultMapPage extends StatefulWidget {
  const DefaultMapPage({super.key});

  @override
  State<DefaultMapPage> createState() => _DefaultMapPageState();
}

class _DefaultMapPageState extends State<DefaultMapPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Constantes
  static const Duration _resizeDebounceDelay = Duration(milliseconds: 80);
  static const Duration _gpsTimeout = Duration(seconds: 8);
  static const int _gpsDistanceFilter = 8;
  static const Duration _menuAnimationDuration = Duration(milliseconds: 300);
  static const Duration _navCloseDelay = Duration(milliseconds: 1500);
  static const int _trackingIntervalSeconds = 15;

  ui.Size? _lastMapSize;
  int _mapRebuildTick = 0;
  Timer? _resizeDebounce;

  // Géolocalisation
  StreamSubscription<Position>? _positionSub;
  double? _userLat;
  double? _userLng;
  bool _requestingGps = false;
  bool _didNotifyMapReady = false;

  // UI
  bool _showActionsMenu = false;
  late AnimationController _menuAnimController;
  late Animation<Offset> _menuSlideAnimation;
  _MapAction? _selectedAction;

  // Tracking
  final GeolocationService _geo = GeolocationService.instance;
  bool _isTracking = false;
  String? _userGroupId;

  // Projets cartographiques
  String? _selectedMapProjectId;
  String _styleUrl = 'mapbox://styles/mapbox/streets-v12';
  double? _projectCenterLat;
  double? _projectCenterLng;
  double? _projectZoom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _isTracking = _geo.isTracking;

    _menuAnimController = AnimationController(
      duration: _menuAnimationDuration,
      vsync: this,
    );
    _menuSlideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _menuAnimController,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
        );

    _bootstrapLocation();
    _loadUserGroupId();

    // Si la carte ne peut pas être affichée (non-web / token manquant),
    // on ne bloque pas le splash indéfiniment.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!kIsWeb || MapboxTokenService.getTokenSync().isEmpty) {
        _notifyMapReady();
      }
    });
  }

  void _notifyMapReady() {
    if (_didNotifyMapReady) return;
    _didNotifyMapReady = true;
    if (!mapReadyNotifier.value) {
      mapReadyNotifier.value = true;
    }
  }

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    _positionSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _menuAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadUserGroupId() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || !mounted) return;
      final groupId = doc.data()?['groupId'] as String?;
      setState(() => _userGroupId = groupId);
    } catch (e) {
      debugPrint('Erreur chargement groupId: $e');
    }
  }

  Gradient _headerLanguageFlagGradient() {
    final langService = Get.find<LanguageService>();
    switch (langService.currentLanguageCode) {
      case 'fr':
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0055A4), Color(0xFFFFFFFF), Color(0xFFEF4135)],
          stops: [0.0, 0.5, 1.0],
        );
      case 'en':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF012169), Color(0xFFC8102E)],
          stops: [0.4, 0.6],
        );
      case 'es':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC60B1E), Color(0xFFFFC400), Color(0xFFC60B1E)],
          stops: [0.0, 0.5, 1.0],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF0066FF), Color(0xFF0066FF)],
        );
    }
  }

  String _headerLanguageCode() {
    final langService = Get.find<LanguageService>();
    return langService.currentLanguageCode.toUpperCase();
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

  void _recenterOnUser() {
    final lat = _userLat;
    final lng = _userLng;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position GPS indisponible pour centrer la carte.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _projectCenterLat = lat;
      _projectCenterLng = lng;
      _projectZoom = 15.5;
      _mapRebuildTick++;
    });
  }

  void _selectAction(_MapAction action, String label) {
    setState(() => _selectedAction = action);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mode "$label" sélectionné.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _geo.stopTracking();
      if (mounted) setState(() => _isTracking = false);
      return;
    }

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connecte-toi pour démarrer le tracking.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final groupId = _userGroupId;
    if (groupId == null || groupId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun groupId associé à ton profil.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final ok = await _geo.startTracking(
      groupId: groupId,
      intervalSeconds: _trackingIntervalSeconds,
    );
    if (!mounted) return;
    setState(() => _isTracking = ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '✅ Tracking démarré (${_trackingIntervalSeconds}s)'
              : '❌ Permissions GPS refusées',
        ),
      ),
    );
  }

  void _showMapProjectsSelector() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Projets cartographiques',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('map_projects')
                      .where('status', isEqualTo: 'published')
                      .where('isVisible', isEqualTo: true)
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF9B6BFF),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucun projet disponible',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    final now = Timestamp.now();
                    final filteredDocs = snapshot.data!.docs.where((doc) {
                      final publishAt = doc.get('publishAt') as Timestamp?;
                      return publishAt == null || publishAt.compareTo(now) <= 0;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucun projet publié',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final name = doc.get('name') ?? 'Sans nom';
                        final countryId = doc.get('countryId') ?? '';
                        final eventId = doc.get('eventId') ?? '';
                        final isSelected = _selectedMapProjectId == doc.id;

                        return ListTile(
                          leading: Icon(
                            Icons.map,
                            color: isSelected
                                ? const Color(0xFF9B6BFF)
                                : Colors.white70,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF9B6BFF)
                                  : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '$countryId / $eventId',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Color(0xFF9B6BFF),
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedMapProjectId = doc.id;
                            });
                            _applyMapProject(doc);
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyMapProject(DocumentSnapshot project) {
    try {
      final styleUrl = project.get('styleUrl') as String?;
      if (styleUrl != null && styleUrl.isNotEmpty) {
        _styleUrl = styleUrl;
      }

      final perimeter = project.get('perimeter') as List<dynamic>?;
      if (perimeter != null && perimeter.isNotEmpty) {
        final points = perimeter
            .whereType<Map<String, dynamic>>()
            .map(
              (p) => _LatLng(
                lat: (p['lat'] as num).toDouble(),
                lng: (p['lng'] as num).toDouble(),
              ),
            )
            .toList();

        final bounds = _calculateBounds(points);
        if (bounds != null) {
          final latDiff = bounds.maxLat - bounds.minLat;
          final lngDiff = bounds.maxLng - bounds.minLng;
          _projectCenterLat = (bounds.minLat + bounds.maxLat) / 2;
          _projectCenterLng = (bounds.minLng + bounds.maxLng) / 2;
          _projectZoom = _calculateOptimalZoom(latDiff, lngDiff);
        }
      }

      if (mounted) {
        setState(() => _mapRebuildTick++);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement projet: $e');
    }
  }

  _Bounds? _calculateBounds(List<_LatLng> points) {
    if (points.isEmpty) return null;
    var minLng = points.first.lng;
    var maxLng = points.first.lng;
    var minLat = points.first.lat;
    var maxLat = points.first.lat;
    for (final pt in points) {
      if (pt.lng < minLng) minLng = pt.lng;
      if (pt.lng > maxLng) maxLng = pt.lng;
      if (pt.lat < minLat) minLat = pt.lat;
      if (pt.lat > maxLat) maxLat = pt.lat;
    }
    return _Bounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }

  double _calculateOptimalZoom(double latDiff, double lngDiff) {
    const zoomThresholdLarge = 0.1;
    const zoomThresholdMedium = 0.01;
    const zoomLevelLarge = 10.0;
    const zoomLevelMedium = 12.0;
    const zoomLevelSmall = 14.0;

    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    if (maxDiff > zoomThresholdLarge) return zoomLevelLarge;
    if (maxDiff > zoomThresholdMedium) return zoomLevelMedium;
    return zoomLevelSmall;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) {
      try {
        setState(() => _mapRebuildTick++);
      } catch (e) {
        debugPrint('⚠️ Erreur didChangeMetrics: $e');
      }
    }
  }

  void _scheduleResize(ui.Size size) {
    if (_lastMapSize == size) return;
    _lastMapSize = size;

    _resizeDebounce?.cancel();

    _resizeDebounce = Timer(_resizeDebounceDelay, () {
      if (!mounted) return;

      try {
        setState(() => _mapRebuildTick++);
        debugPrint(
          '✅ Default map resize: ${size.width.toInt()}x${size.height.toInt()} '
          '(tick: $_mapRebuildTick)',
        );
      } catch (e) {
        debugPrint('⚠️ Erreur _scheduleResize: $e');
      }
    });
  }

  /// Initialise la géolocalisation au démarrage
  Future<void> _bootstrapLocation() async {
    final ok = await _ensureLocationPermission(request: true);

    if (ok) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: _gpsTimeout,
          ),
        );
        if (mounted) {
          setState(() {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
          });
        }
      } on TimeoutException catch (e) {
        debugPrint('⏱️ Timeout GPS: $e');
      } catch (e) {
        debugPrint('⚠️ Erreur GPS: $e');
      }
    }

    if (ok) {
      _startUserPositionStream();
    }
  }

  /// Vérifie et demande les permissions de géolocalisation
  Future<bool> _ensureLocationPermission({required bool request}) async {
    if (_requestingGps) return false;
    _requestingGps = true;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Active la localisation (GPS).'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission GPS refusée.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission GPS refusée définitivement.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
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

  /// Démarre le stream de position en temps réel
  void _startUserPositionStream() {
    _positionSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: _gpsDistanceFilter,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (pos) {
            if (!mounted) return;
            setState(() {
              _userLat = pos.latitude;
              _userLng = pos.longitude;
            });
          },
          onError: (error) {
            debugPrint('⚠️ Erreur stream position: $error');
          },
          cancelOnError: false,
        );
  }

  @override
  Widget build(BuildContext context) {
    final token = MapboxTokenService.getTokenSync();

    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carte par défaut')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cette page est uniquement disponible sur Web.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (token.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carte par défaut')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Token Mapbox manquant.\nConfigure MAPBOX_ACCESS_TOKEN.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = ui.Size(constraints.maxWidth, constraints.maxHeight);
            final topInset = MediaQuery.of(context).padding.top;
            final menuTopOffset = topInset + 104;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scheduleResize(size);
            });

            return Stack(
              children: [
                // Bandeau blanc derrière la status bar
                if (topInset > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topInset,
                    child: const ColoredBox(color: Colors.white),
                  ),

                // Carte Mapbox en plein écran
                Positioned.fill(
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: Container(
                        color: Colors.transparent,
                        child: MapboxWebView(
                          key: ValueKey(
                            'default-map-${size.width.toInt()}x${size.height.toInt()}_$_mapRebuildTick',
                          ),
                          accessToken: token,
                          initialLat: _projectCenterLat ?? _userLat ?? 16.2410,
                          initialLng: _projectCenterLng ?? _userLng ?? -61.5340,
                          initialZoom:
                              _projectZoom ?? (_userLat != null ? 15.0 : 13.0),
                          initialPitch: 0.0,
                          initialBearing: 0.0,
                          styleUrl: _styleUrl,
                          userLat: _userLat,
                          userLng: _userLng,
                          showUserLocation:
                              true, // Afficher le marqueur de position
                          onMapReady: _notifyMapReady,
                        ),
                      ),
                    ),
                  ),
                ),

                // Overlay actions menu (vertical) + backdrop
                if (_showActionsMenu)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        _menuAnimController.reverse();
                        Future.delayed(_menuAnimationDuration, () {
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
                            margin: EdgeInsets.only(
                              right: 0,
                              top: menuTopOffset,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
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
                                    label: 'Cartes',
                                    icon: Icons.layers_rounded,
                                    selected: _selectedMapProjectId != null,
                                    onTap: () {
                                      // Reprend la fonctionnalité de l'ancienne icône "Projets"
                                      _showMapProjectsSelector();
                                      _closeNavWithDelay();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _ActionItem(
                                    label: 'Centrer',
                                    icon: Icons.my_location_rounded,
                                    selected: false,
                                    onTap: () {
                                      _recenterOnUser();
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
                                    label: l10n.AppLocalizations.of(
                                      context,
                                    )!.visit,
                                    icon: Icons.map_outlined,
                                    selected:
                                        _selectedAction == _MapAction.visiter,
                                    onTap: () {
                                      _selectAction(
                                        _MapAction.visiter,
                                        'Visiter',
                                      );
                                      _closeNavWithDelay();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _ActionItem(
                                    label: l10n.AppLocalizations.of(
                                      context,
                                    )!.food,
                                    icon: Icons.fastfood_rounded,
                                    selected:
                                        _selectedAction == _MapAction.food,
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
                                        _selectedAction ==
                                        _MapAction.assistance,
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
                                    label: l10n.AppLocalizations.of(
                                      context,
                                    )!.parking,
                                    icon: Icons.local_parking_rounded,
                                    selected:
                                        _selectedAction == _MapAction.parking,
                                    onTap: () {
                                      _selectAction(
                                        _MapAction.parking,
                                        'Parking',
                                      );
                                      _closeNavWithDelay();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _ActionItem(
                                    label: '',
                                    icon: Icons.wc_rounded,
                                    selected: _selectedAction == _MapAction.wc,
                                    onTap: () {
                                      _selectAction(_MapAction.wc, 'WC');
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
                        Tooltip(
                          message: l10n.AppLocalizations.of(context)!.language,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _cycleLanguage,
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: _headerLanguageFlagGradient(),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF9B6BFF,
                                      ).withValues(alpha: 0.22),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF7AAE,
                                      ).withValues(alpha: 0.16),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _headerLanguageCode(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                            setState(
                              () => _showActionsMenu = !_showActionsMenu,
                            );
                            if (_showActionsMenu) {
                              _menuAnimController.forward();
                            } else {
                              _menuAnimController.reverse();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LatLng {
  final double lat;
  final double lng;

  const _LatLng({required this.lat, required this.lng});
}

class _Bounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const _Bounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}

class _ActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ActionItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

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
          border: Border.all(
            color: selected ? MasliveTheme.pink : MasliveTheme.divider,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected ? MasliveTheme.cardShadow : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: label.isEmpty ? 32 : 28,
              color: selected ? MasliveTheme.pink : MasliveTheme.textPrimary,
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
                        ? MasliveTheme.pink
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
                      ? 'Actif (${_DefaultMapPageState._trackingIntervalSeconds}s)'
                      : 'Inactif',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MasliveTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onToggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: isTracking
                  ? MasliveTheme.pink
                  : const Color(0xFF9B6BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(isTracking ? 'Stop' : 'Start'),
          ),
        ],
      ),
    );
  }
}
