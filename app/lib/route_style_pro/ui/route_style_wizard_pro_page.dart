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

  const RouteStyleProArgs({
    this.projectId,
    this.circuitId,
    this.initialRoute,
  });
}

class RouteStyleWizardProPage extends StatefulWidget {
  final String? projectId;
  final String? circuitId;
  final List<LatLng>? initialRoute;

  const RouteStyleWizardProPage({
    super.key,
    this.projectId,
    this.circuitId,
    this.initialRoute,
  });

  @override
  State<RouteStyleWizardProPage> createState() => _RouteStyleWizardProPageState();
}

class _RouteStyleWizardProPageState extends State<RouteStyleWizardProPage> {
  final _persistence = RouteStylePersistence();
  final _snapService = RouteSnapService();

  bool _loading = true;
  bool _busy = false;

  RouteStyleConfig _config = const RouteStyleConfig();
  RouteStyleConfig _renderConfig = const RouteStyleConfig();

  Timer? _debounce;

  List<LatLng> _route = const [];

  String? get _projectId => widget.projectId;
  String? get _circuitId => widget.circuitId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final remote = await _persistence.loadRemote(projectId: _projectId, circuitId: _circuitId);
      final local = await _persistence.loadLocal();
      final cfg = (remote ?? local ?? const RouteStyleConfig()).validated();

      final initialRoute = widget.initialRoute;
      List<LatLng> route;
      if (initialRoute != null) {
        route = initialRoute;
      } else if ((_projectId ?? '').trim().isNotEmpty) {
        route = await _loadProjectRoute(_projectId!);
      } else {
        route = _defaultTestRoute();
      }

      if (!mounted) return;
      setState(() {
        _config = cfg;
        _renderConfig = cfg;
        _route = route;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<LatLng>> _loadProjectRoute(String projectId) async {
    final doc = await FirebaseFirestore.instance.collection('map_projects').doc(projectId).get();
    final data = doc.data();
    final current = (data?['current'] is Map) ? Map<String, dynamic>.from(data?['current'] as Map) : null;
    final raw = (current != null && current['route'] is List) ? current['route'] : data?['route'];
    if (raw is! List) return const [];

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
    return out;
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

    final start = (_route.isNotEmpty) ? _route.first : _defaultTestRoute().first;
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
      final route = await _loadProjectRoute(pid!);
      if (!mounted) return;
      setState(() => _route = route);
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
      final cfg = _config.validated();
      await _persistence.saveLocal(cfg);
      await _persistence.saveRemote(cfg, projectId: _projectId, circuitId: _circuitId);
      _snack('Style enregistré');
    } catch (e) {
      _snack('Sauvegarde échouée: ${e.toString()}');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Style Wizard Pro'),
        actions: [
          if ((_projectId ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'project: ${_projectId!}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: _loading
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
                      ),
                    ),
                    if (_busy)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Color(0x11000000),
                            child: Center(child: CircularProgressIndicator()),
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
    );
  }
}
