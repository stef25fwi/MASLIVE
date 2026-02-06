import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/latlng.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/gradient_icon_button.dart';
import '../ui/widgets/maslive_card.dart';
import '../ui/widgets/maslive_profile_icon.dart';
import '../ui/widgets/mapbox_web_view.dart';
import '../models/map_preset_model.dart';
import '../pages/map_selector_page.dart';
import '../services/auth_service.dart';
import '../services/geolocation_service.dart';
import '../services/language_service.dart';
import '../services/map_presets_service.dart';
import '../services/mapbox_token_service.dart';
import '../l10n/app_localizations.dart' as l10n;
import 'splash_wrapper_page.dart' show mapReadyNotifier;
import '../ui/widgets/mapbox_token_dialog.dart';

enum _MapAction { ville, tracking, visiter, encadrement, food, wc, parking }

class HomeMapPageWeb extends StatefulWidget {
  const HomeMapPageWeb({super.key});

  @override
  State<HomeMapPageWeb> createState() => _HomeMapPageWebState();
}

class _HomeMapPageWebState extends State<HomeMapPageWeb>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  _MapAction _selected = _MapAction.ville;
  bool _showActionsMenu = false;
  late AnimationController _menuAnimController;
  late Animation<Offset> _menuSlideAnimation;

  static const Duration _menuOpenDelay = Duration.zero;
  // Offset vertical du menu d'actions pour ne pas chevaucher la boussole
  static const double _actionsMenuTopOffset = 160;

  final GeolocationService _geo = GeolocationService.instance;
  final MapPresetsService _presetService = MapPresetsService();

  StreamSubscription<Position>? _positionSub;
  LatLng? _userPos;
  bool _requestingGps = false;
  bool _isTracking = false;
  bool _isMapReady = false;
  bool _isGpsReady = false;

  String _runtimeMapboxToken = '';

  // Variables pour la gestion des cartes pré-enregistrées
  MapPresetModel? _selectedPreset;
  List<LayerModel> _currentPresetLayers = [];
  Map<String, bool> _activeLayers = {};
  String? _userGroupId;
  bool _isSuperAdmin = false;

  static const LatLng _fallbackCenter = LatLng(16.241, -61.533);

  String get _effectiveMapboxToken => _runtimeMapboxToken.isNotEmpty
      ? _runtimeMapboxToken
      : MapboxTokenService.getTokenSync();

  bool get _useMapboxTiles => _effectiveMapboxToken.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('🗺️ HomeMapPageWeb: initState called');
    _isTracking = _geo.isTracking;
    _menuAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    _bootstrapLocation();
    _loadUserGroupId();
    _loadRuntimeMapboxToken();
  }

  Future<void> _loadRuntimeMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (!mounted) return;
      setState(() {
        _runtimeMapboxToken = info.token;
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
    setState(() {
      _runtimeMapboxToken = newToken;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _menuAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('🗺️ HomeMapPageWeb: App resumed, relancer GPS');
        _bootstrapLocation();
        break;
      case AppLifecycleState.paused:
        debugPrint('🗺️ HomeMapPageWeb: App paused');
        break;
      case AppLifecycleState.detached:
        debugPrint('🗺️ HomeMapPageWeb: App detached');
        break;
      case AppLifecycleState.inactive:
        debugPrint('🗺️ HomeMapPageWeb: App inactive');
        break;
      case AppLifecycleState.hidden:
        debugPrint('🗺️ HomeMapPageWeb: App hidden');
        break;
    }
  }

  Future<void> _bootstrapLocation() async {
    final ok = await _ensureLocationPermission(request: true);

    if (ok) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 8),
          ),
        );
        final p = LatLng(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            _userPos = p;
          });
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lors de la récupération de la position: $e');
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

  Future<bool> _ensureLocationPermission({required bool request}) async {
    if (_requestingGps) return false;
    _requestingGps = true;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } finally {
      _requestingGps = false;
    }
  }

  void _startUserPositionStream() {
    _positionSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 8,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
          final p = LatLng(pos.latitude, pos.longitude);
          if (!mounted) return;

          setState(() {
            _userPos = p;
            if (!_isGpsReady) {
              _isGpsReady = true;
              _checkIfReady();
            }
          });
        });
  }

  void _checkIfReady() {
    if (_isMapReady && !mapReadyNotifier.value) {
      debugPrint('✅ HomeMapPageWeb: Carte prête, notification du splashscreen');
      Future.delayed(const Duration(milliseconds: 300), () {
        mapReadyNotifier.value = true;
      });
    }
  }

  void _onMapReady() {
    debugPrint('🗺️ HomeMapPageWeb: Carte Mapbox GL JS prête');
    setState(() {
      _isMapReady = true;
      _checkIfReady();
    });
  }

  Future<void> _recenterOnUser() async {
    final ok = await _ensureLocationPermission(request: true);
    if (!ok) return;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 10),
      ),
    );

    final p = LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;

    setState(() {
      _userPos = p;
    });
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _geo.stopTracking();
      setState(() => _isTracking = false);
      return;
    }

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final profile = await AuthService.instance.getUserProfile(uid);
    if (!mounted) return;
    final groupId = profile?.groupId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final ok = await _geo.startTracking(groupId: groupId, intervalSeconds: 15);
    if (!mounted) return;
    setState(() => _isTracking = ok);
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

  void _toggleActionsMenu() {
    if (_showActionsMenu) {
      _menuAnimController.reverse();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _showActionsMenu) {
          setState(() => _showActionsMenu = false);
        }
      });
      return;
    }

    setState(() => _showActionsMenu = true);
    // Démarrer l'animation immédiatement depuis la position cachée (droite)
    _menuAnimController.forward(from: 0.0);
  }

  void _closeNavWithDelay() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _showActionsMenu) {
        _menuAnimController.reverse();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _showActionsMenu) {
            setState(() => _showActionsMenu = false);
          }
        });
      }
    });
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
      debugPrint('Erreur lors du chargement du groupId: $e');
    }
  }

  void _openMapSelector() {
    if (_userGroupId == null || _userGroupId!.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectorPage(
          groupId: _userGroupId!,
          initialPreset: _selectedPreset,
          isReadOnly: !_isSuperAdmin,
          onMapSelected: (preset, visibleLayers) {
            _applyPreset(preset, visibleLayers: visibleLayers);
          },
        ),
      ),
    );

    _closeNavWithDelay();
  }

  Future<void> _openMapQuickMenu() async {
    if (!_isSuperAdmin) {
      _openMapSelector();
      return;
    }

    if (_userGroupId == null || _userGroupId!.isEmpty) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.layers_rounded, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 10),
                  const Text(
                    'Cartes du groupe',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: l10n.AppLocalizations.of(
                      context,
                    )!.openAdvancedSelector,
                    onPressed: () {
                      Navigator.pop(context);
                      _openMapSelector();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<MapPresetModel>>(
                stream: _presetService.getGroupPresetsStream(_userGroupId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final presets = snapshot.data ?? const <MapPresetModel>[];
                  if (presets.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Aucune carte enregistrée pour ce groupe.'),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: presets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      final isSelected = _selectedPreset?.id == preset.id;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFFB66CFF,
                          ).withValues(alpha: 0.16),
                          child: Icon(
                            Icons.map_rounded,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        title: Text(
                          preset.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          preset.description.isNotEmpty
                              ? preset.description
                              : 'Centre: ${preset.center.latitude.toStringAsFixed(3)}, ${preset.center.longitude.toStringAsFixed(3)}',
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Confirmer le chargement ?'),
                              content: Text(
                                'Charger "${preset.title}" et ses couches associées ?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Confirmer'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            Navigator.pop(context);
                            _applyPreset(preset);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    _closeNavWithDelay();
  }

  void _applyPreset(MapPresetModel preset, {List<LayerModel>? visibleLayers}) {
    final layers = visibleLayers ?? preset.layers;

    setState(() {
      _selectedPreset = preset;
      _currentPresetLayers = List<LayerModel>.from(preset.layers);
      _activeLayers = {for (final layer in layers) layer.id: layer.visible};
    });
  }

  void _toggleLayer(String layerId, bool value) {
    setState(() {
      _activeLayers[layerId] = value;
    });
  }

  void _openLanguagePicker() {
    final langService = Get.find<LanguageService>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        Widget item(Locale lang, String label) {
          final selected = langService.locale == lang;
          return ListTile(
            leading: Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? MasliveTheme.textPrimary
                  : MasliveTheme.textSecondary,
            ),
            title: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: MasliveTheme.textPrimary,
              ),
            ),
            onTap: () {
              langService.changeLanguage(lang.languageCode);
              Navigator.pop(context);
            },
          );
        }

        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 80, 12, 0),
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                boxShadow: MasliveTheme.floatingShadow,
                border: Border.all(color: MasliveTheme.divider),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Langue',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: MasliveTheme.textPrimary,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  item(const Locale('en'), 'English'),
                  item(const Locale('fr'), 'Français'),
                  item(const Locale('es'), 'Español'),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _userPos ?? _fallbackCenter;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // Carte Mapbox GL JS via HtmlElementView
            Positioned.fill(
              child: _useMapboxTiles
                  ? MapboxWebView(
                      accessToken: _effectiveMapboxToken,
                      initialLat: center.latitude,
                      initialLng: center.longitude,
                      initialZoom: 15.5,
                      initialPitch: 45.0,
                      initialBearing: 0.0,
                      styleUrl: 'mapbox://styles/mapbox/streets-v12',
                      userLat: _userPos?.latitude,
                      userLng: _userPos?.longitude,
                      showUserLocation: _userPos != null,
                      onMapReady: _onMapReady,
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.map_outlined,
                                size: 64,
                                color: Colors.black54,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Mapbox inactif: MAPBOX_ACCESS_TOKEN manquant',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _configureMapboxToken,
                                icon: const Icon(Icons.settings),
                                label: const Text('Configurer'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),

            // Boussole (demi-flèche rouge)
            const Positioned(top: 104, right: 14, child: _HalfRedCompass()),

            // Overlay actions - affiche quand burger cliqué
            Positioned.fill(
              child: Visibility(
                visible: _showActionsMenu,
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
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! > 0) {
                      _menuAnimController.reverse();
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() => _showActionsMenu = false);
                        }
                      });
                    }
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
                          boxShadow: const [],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSuperAdmin)
                                _ActionItem(
                                  label: 'Cartes',
                                  icon: Icons.layers_rounded,
                                  selected: _selectedPreset != null,
                                  onTap: _openMapQuickMenu,
                                ),
                              if (_isSuperAdmin) const SizedBox(height: 8),
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
                                selected: _selected == _MapAction.tracking,
                                onTap: () {
                                  setState(() {
                                    _selected = _MapAction.tracking;
                                  });
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: l10n.AppLocalizations.of(context)!.visit,
                                icon: Icons.map_outlined,
                                selected: _selected == _MapAction.visiter,
                                onTap: () {
                                  setState(() {
                                    _selected = _MapAction.visiter;
                                  });
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: l10n.AppLocalizations.of(context)!.food,
                                icon: Icons.fastfood_rounded,
                                selected: _selected == _MapAction.food,
                                onTap: () {
                                  setState(() {
                                    _selected = _MapAction.food;
                                  });
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: l10n.AppLocalizations.of(
                                  context,
                                )!.assistance,
                                icon: Icons.shield_outlined,
                                selected: _selected == _MapAction.encadrement,
                                onTap: () {
                                  setState(() {
                                    _selected = _MapAction.encadrement;
                                  });
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
                                selected: _selected == _MapAction.parking,
                                onTap: () {
                                  setState(() {
                                    _selected = _MapAction.parking;
                                  });
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
                                highlightBackgroundOnSelected: false,
                                showBorder: false,
                                selected: _selected == _MapAction.wc,
                                onTap: () {
                                  setState(() {
                                    _selected = _MapAction.wc;
                                  });
                                  _cycleLanguage();
                                  _closeNavWithDelay();
                                },
                                onLongPress: _openLanguagePicker,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Panneau rapide des couches actives (si un preset est chargé)
            if (_selectedPreset != null && _currentPresetLayers.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                bottom: _selected == _MapAction.tracking ? 96 : 36,
                child: _LayerQuickPanel(
                  layers: _currentPresetLayers,
                  activeLayers: _activeLayers,
                  onToggle: _toggleLayer,
                ),
              ),

            if (_selected == _MapAction.tracking)
              Positioned(
                left: 16,
                right: 90,
                bottom: 18,
                child: _TrackingPill(
                  isTracking: _isTracking,
                  onToggle: _toggleTracking,
                ),
              ),

            // Header déplacé en bas comme bottom bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MasliveGradientHeader(
                height: 60,
                borderRadius: BorderRadius.zero,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                backgroundColor: Colors.white.withValues(alpha: 0.65),
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
                                _closeNavWithDelay();
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    if (mounted) {
                                      Navigator.pushNamed(
                                        context,
                                        '/account-ui',
                                      );
                                    }
                                  },
                                );
                              } else {
                                _closeNavWithDelay();
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    if (mounted) {
                                      Navigator.pushNamed(context, '/login');
                                    }
                                  },
                                );
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
                        _closeNavWithDelay();
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) {
                            Navigator.pushNamed(context, '/shop-ui');
                          }
                        });
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
  final VoidCallback? onLongPress;
  final bool fullBleed;
  final bool tintOnSelected;
  final bool highlightBackgroundOnSelected;
  final bool showBorder;

  const _ActionItem({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.fullBleed = false,
    this.tintOnSelected = true,
    this.highlightBackgroundOnSelected = true,
    this.showBorder = true,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    final showSelectedBackground = highlightBackgroundOnSelected && selected;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: showSelectedBackground
                  ? MasliveTheme.actionGradient
                  : null,
              color: showSelectedBackground
                  ? null
                  : Colors.white.withValues(alpha: 0.92),
              border: showBorder
                  ? Border.all(
                      color: selected
                          ? MasliveTheme.pink
                          : MasliveTheme.divider,
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
                        if (iconWidget != null)
                          selected && tintOnSelected
                              ? ColorFiltered(
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                  child: iconWidget!,
                                )
                              : iconWidget!,
                        if (icon != null)
                          Center(
                            child: Icon(
                              icon,
                              size: 28,
                              color: selected && tintOnSelected
                                  ? Colors.white
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
                        SizedBox(
                          width: label.isEmpty ? 32 : 28,
                          height: label.isEmpty ? 32 : 28,
                          child: selected && tintOnSelected
                              ? ColorFiltered(
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                  child: iconWidget!,
                                )
                              : iconWidget!,
                        )
                      else
                        Icon(
                          icon,
                          size: label.isEmpty ? 32 : 28,
                          color: selected && tintOnSelected
                              ? Colors.white
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
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: selected && tintOnSelected
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
        ],
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
                  isTracking ? 'Actif (15s)' : 'Inactif',
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

class _LayerQuickPanel extends StatelessWidget {
  final List<LayerModel> layers;
  final Map<String, bool> activeLayers;
  final void Function(String layerId, bool value) onToggle;

  const _LayerQuickPanel({
    required this.layers,
    required this.activeLayers,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(Icons.layers_rounded, size: 18, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text(
                'Couches actives',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final layer in layers)
                FilterChip(
                  label: Text(
                    layer.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  avatar: Icon(
                    layer.iconName != null ? Icons.checklist_rtl : Icons.layers,
                    size: 18,
                  ),
                  selected: activeLayers[layer.id] ?? layer.visible,
                  onSelected: (value) => onToggle(layer.id, value),
                  selectedColor: const Color(
                    0xFFB66CFF,
                  ).withValues(alpha: 0.18),
                  checkmarkColor: const Color(0xFF7C3AED),
                  side: BorderSide(
                    color: (activeLayers[layer.id] ?? layer.visible)
                        ? const Color(0xFF7C3AED)
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
