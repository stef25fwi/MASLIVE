import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/route_style_config.dart';
import '../services/route_snap_service.dart';
import '../services/route_style_persistence.dart';
import 'widgets/route_style_controls_panel.dart';
import 'widgets/route_style_preview_map.dart';

class RouteStyleProArgs {
  final String? projectId;
  final String? circuitId;
  final List<LatLng>? initialRoute;
  final String? initialStyleUrl;

  const RouteStyleProArgs({
    this.projectId,
    this.circuitId,
    this.initialRoute,
    this.initialStyleUrl,
  });
}

class RouteStyleWizardProPage extends StatefulWidget {
  final String? projectId;
  final String? circuitId;
  final List<LatLng>? initialRoute;
  final String? initialStyleUrl;

  const RouteStyleWizardProPage({
    super.key,
    this.projectId,
    this.circuitId,
    this.initialRoute,
    this.initialStyleUrl,
  });

  @override
  State<RouteStyleWizardProPage> createState() =>
      _RouteStyleWizardProPageState();
}

class _RouteStyleWizardProPageState extends State<RouteStyleWizardProPage> {
  final _persistence = RouteStylePersistence();
  final _snapService = RouteSnapService();

  bool _canPopNow = false;
  bool _popHandlerInFlight = false;

  bool _loading = true;
  bool _busy = false;

  RouteStyleConfig _config = const RouteStyleConfig();
  RouteStyleConfig _renderConfig = const RouteStyleConfig();

  Timer? _debounce;
  Timer? _autosaveDebounce;

  bool _hasUnsavedChanges = false;
  bool _persisting = false;
  Future<void>? _persistInFlight;

  List<LatLng> _route = const [];
  String? _baseStyleUrl;

  String? get _projectId => widget.projectId;
  String? get _circuitId => widget.circuitId;

  static const int _wizardCurrentStep = 4; // Style Pro

  String _getWizardStepLabel(int step) {
    const labels = [
      'Template',
      'Infos',
      'Périmètre',
      'Tracé + Style',
      'Style Pro',
      'POI',
      'Pré-pub',
      'Publication',
    ];
    return labels[step.clamp(0, labels.length - 1)];
  }

  Widget _buildWizardHeader() {
    Widget buildStep(int index) {
      return Expanded(
        child: _WizardStepIndicator(
          step: index,
          label: _getWizardStepLabel(index),
          isActive: index == _wizardCurrentStep,
          isCompleted: index < _wizardCurrentStep,
          isEnabled: true,
        ),
      );
    }

    return SizedBox(
      height: 112,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                for (final i in [0, 1, 2, 3]) buildStep(i),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                for (final i in [4, 5, 6, 7]) buildStep(i),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autosaveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _persistIfNeeded({required bool showSnack}) async {
    if (_persisting) {
      // Si on demande explicitement une action (save/flush), on attend.
      if (showSnack) {
        await (_persistInFlight ?? Future<void>.value());
      }
      return;
    }
    if (!_hasUnsavedChanges) return;

    final pid = (_projectId ?? '').trim();
    final cid = (_circuitId ?? '').trim();

    // Toujours persister en local; remote uniquement si contexte présent.
    final cfg = _config.validated();

    _persisting = true;
    _hasUnsavedChanges = false;

    Future<void> doPersist() async {
      await _persistence.saveLocal(cfg);
      if (pid.isNotEmpty || cid.isNotEmpty) {
        await _persistence.saveRemote(
          cfg,
          projectId: _projectId,
          circuitId: _circuitId,
        );
      }
    }

    final future = doPersist();
    _persistInFlight = future;

    try {
      await future;
      if (showSnack) _snack('Style enregistré');
    } catch (e) {
      // Si la persistance échoue, on garde le dirty flag.
      _hasUnsavedChanges = true;
      if (showSnack) _snack('Sauvegarde échouée: ${e.toString()}');
    } finally {
      _persisting = false;
      if (identical(_persistInFlight, future)) _persistInFlight = null;
    }
  }

  void _scheduleAutosave() {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      // Fire-and-forget: on ne bloque pas l'UI pendant le réglage.
      unawaited(_persistIfNeeded(showSnack: false));
    });
  }

  Future<void> _flushAutosave() async {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = null;
    // Attend une écriture en cours, puis persiste tout ce qui reste dirty.
    await (_persistInFlight ?? Future<void>.value());
    await _persistIfNeeded(showSnack: false);
  }

  Future<void> _init() async {
    try {
      final remote = await _persistence.loadRemote(
        projectId: _projectId,
        circuitId: _circuitId,
      );
      final local = await _persistence.loadLocal();
      final cfg = (remote ?? local ?? const RouteStyleConfig()).validated();

      final initialRoute = widget.initialRoute;
      final initialStyleUrl = (widget.initialStyleUrl ?? '').trim();
      List<LatLng> route;
      String? styleUrl;
      if (initialRoute != null) {
        route = initialRoute;
        styleUrl = initialStyleUrl.isEmpty ? null : initialStyleUrl;
        if (styleUrl == null && (_projectId ?? '').trim().isNotEmpty) {
          styleUrl = await _loadProjectStyleUrl(_projectId!);
        }
      } else if ((_projectId ?? '').trim().isNotEmpty) {
        final loaded = await _loadProjectRouteAndStyle(_projectId!);
        route = loaded.route;
        styleUrl = (initialStyleUrl.isNotEmpty)
            ? initialStyleUrl
            : loaded.styleUrl;
      } else {
        route = _defaultTestRoute();
        styleUrl = initialStyleUrl.isEmpty ? null : initialStyleUrl;
      }

      if (!mounted) return;
      setState(() {
        _config = cfg;
        _renderConfig = cfg;
        _route = route;
        _baseStyleUrl = (styleUrl ?? '').trim().isEmpty ? null : styleUrl;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<({List<LatLng> route, String? styleUrl})> _loadProjectRouteAndStyle(
    String projectId,
  ) async {
    final doc = await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(projectId)
        .get();
    final data = doc.data();
    final current = (data?['current'] is Map)
        ? Map<String, dynamic>.from(data?['current'] as Map)
        : null;
    final raw = (current != null && current['route'] is List)
        ? current['route']
        : data?['route'];
    final styleUrl = (data?['styleUrl'] as String?)?.trim();
    if (raw is! List) return (route: const <LatLng>[], styleUrl: styleUrl);

    final out = <LatLng>[];
    for (final p in raw) {
      if (p is Map) {
        final lng = (p['lng'] as num?)?.toDouble();
        final lat = (p['lat'] as num?)?.toDouble();
        if (lng != null && lat != null) {
          out.add((lat: lat, lng: lng));
        }
      }
    }
    return (route: out, styleUrl: styleUrl);
  }

  Future<String?> _loadProjectStyleUrl(String projectId) async {
    final doc = await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(projectId)
        .get();
    final data = doc.data();
    final styleUrl = (data?['styleUrl'] as String?)?.trim();
    return (styleUrl ?? '').isEmpty ? null : styleUrl;
  }

  List<LatLng> _defaultTestRoute() {
    // Petit itinéraire de démo (Pointe-à-Pitre, GP) pour que la page soit utilisable sans contexte.
    return const [
      (lat: 16.2410, lng: -61.5340),
      (lat: 16.2390, lng: -61.5320),
      (lat: 16.2370, lng: -61.5300),
      (lat: 16.2350, lng: -61.5280),
      (lat: 16.2330, lng: -61.5260),
    ];
  }

  void _onConfigChanged(RouteStyleConfig cfg) {
    final next = cfg.validated();
    setState(() => _config = next);

    _hasUnsavedChanges = true;
    _scheduleAutosave();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _renderConfig = _config);
    });
  }

  Future<void> _applySnapIfNeeded({required String label}) async {
    if (_route.length < 2) {
      _snack('Ajoutez au moins 2 points pour snap');
      return;
    }

    setState(() => _busy = true);
    try {
      final snapped = await _snapService.snapToRoad(
        _route,
        options: SnapOptions(
          toleranceMeters: _config.snapToleranceMeters,
          simplifyPercent: _config.simplifyPercent,
        ),
      );
      if (!mounted) return;
      setState(() => _route = snapped.points);
      _snack('$label: OK (${snapped.points.length} pts)');
    } catch (e) {
      _snack('$label: échec (${e.toString()})');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testAutoRoute() async {
    if (_busy) return;

    final start = (_route.isNotEmpty)
        ? _route.first
        : _defaultTestRoute().first;
    final end = (_route.length >= 2) ? _route.last : _defaultTestRoute().last;

    setState(() => _route = [start, end]);
    await _applySnapIfNeeded(label: 'Itinéraire auto');
  }

  Future<void> _useMyTrace() async {
    if (_busy) return;

    final pid = _projectId;
    if ((pid ?? '').trim().isEmpty) {
      _snack('Aucun projectId fourni');
      return;
    }

    setState(() => _busy = true);
    try {
      final loaded = await _loadProjectRouteAndStyle(pid!);
      if (!mounted) return;
      setState(() {
        _route = loaded.route;
        final styleUrl = (loaded.styleUrl ?? '').trim();
        _baseStyleUrl = styleUrl.isEmpty ? null : styleUrl;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (_config.carMode) {
      await _applySnapIfNeeded(label: 'Snap sur route');
    }
  }

  Future<void> _save() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await _persistIfNeeded(showSnack: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    _onConfigChanged(const RouteStyleConfig());
    _snack('Réinitialisé');
  }

  void _snack(String msg) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final media = MediaQuery.of(context);

    // Position juste sous la status bar système en haut
    final top = media.padding.top + 8;
    final viewportH = media.size.height;
    final bottom = (viewportH - top - 72).clamp(0.0, viewportH);

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          dismissDirection: DismissDirection.up,
          margin: EdgeInsets.fromLTRB(16, top, 16, bottom),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const proBlue = Color(0xFF1A73E8);

    return PopScope(
      canPop: _canPopNow,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _popHandlerInFlight = false;
          return;
        }
        if (_popHandlerInFlight) return;
        _popHandlerInFlight = true;

        () async {
          await _flushAutosave();
          if (!mounted) return;

          // Autorise le pop puis relance une demande de pop.
          setState(() => _canPopNow = true);
          final popped = await Navigator.of(this.context).maybePop();
          if (!mounted) return;

          // Si rien n'a pop (ex: route racine), on réarme le blocage.
          if (!popped) {
            setState(() => _canPopNow = false);
            _popHandlerInFlight = false;
          }
        }();
      },
      child: Scaffold(
        body: Column(
          children: [
            _buildWizardHeader(),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, c) {
                        final isWide = c.maxWidth >= 980;

                        final map = Stack(
                          children: [
                            Positioned.fill(
                              child: RouteStylePreviewMap(
                                config: _renderConfig,
                                route: _route,
                                styleUrl: _baseStyleUrl,
                              ),
                            ),
                            if (_busy)
                              const Positioned.fill(
                                child: IgnorePointer(
                                  child: ColoredBox(
                                    color: Color(0x11000000),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );

                        final panel = RouteStyleControlsPanel(
                          config: _config,
                          onChanged: _onConfigChanged,
                          onTestAutoRoute: _busy ? () {} : _testAutoRoute,
                          onUseMyTrace: _busy ? () {} : _useMyTrace,
                          onSave: _busy ? () {} : _save,
                          onReset: _busy ? () {} : _reset,
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(flex: 3, child: map),
                              const VerticalDivider(width: 1),
                              SizedBox(width: 420, child: panel),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            SizedBox(height: 320, child: map),
                            const Divider(height: 1),
                            Expanded(child: panel),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: proBlue,
                        side: BorderSide(
                          color: proBlue.withValues(alpha: 0.45),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: (_busy || _loading)
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await _flushAutosave();
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop('previous');
                            },
                      child: const Text('← Précédent'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: (_busy || _loading) ? null : _save,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Sauvegarder'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1D2330),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: (_busy || _loading)
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await _flushAutosave();
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop('next');
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: proBlue,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Suivant →'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WizardStepIndicator extends StatelessWidget {
  final int step;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final bool isEnabled;

  const _WizardStepIndicator({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final circleColor = isCompleted
        ? Colors.green
        : isActive
        ? Colors.blue
        : isEnabled
        ? Colors.grey.shade300
        : Colors.grey.shade200;

    final circleTextColor = (isActive || isCompleted)
        ? Colors.white
        : isEnabled
        ? Colors.black
        : Colors.black38;

    final labelColor = isEnabled || isActive ? null : Colors.black38;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: circleTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: labelColor,
            ),
          ),
        ),
      ],
    );
  }
}
