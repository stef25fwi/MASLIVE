import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  CollectionReference<Map<String, dynamic>>? _presetsColForCurrentUser() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if ((uid ?? '').trim().isEmpty) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('routeStyleProPresets');
  }

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

  Future<void> _openPresetsDialog() async {
    final col = _presetsColForCurrentUser();
    if (col == null) {
      _snack('Connectez-vous pour utiliser les presets.');
      return;
    }

    final presetsStream = col
        .orderBy('updatedAt', descending: true)
        .limit(40)
        .snapshots();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Presets Style Pro'),
        content: SizedBox(
          width: 520,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: presetsStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('❌ Erreur de chargement des presets.');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Text('Aucun preset enregistré.');
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: docs.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final data = docs[i].data();
                  final name = (data['name'] as String?)?.trim();
                  final label = (name == null || name.isEmpty)
                      ? 'Preset ${i + 1}'
                      : name;

                  return ListTile(
                    title: Text(label),
                    subtitle: const Text('Appuyer pour appliquer'),
                    onTap: () {
                      final raw = data['config'];
                      if (raw is Map) {
                        final cfg = RouteStyleConfig.fromJson(
                          Map<String, dynamic>.from(raw),
                        ).validated();
                        _onConfigChanged(cfg);
                        Navigator.pop(ctx);
                      } else {
                        _snack('Preset invalide (config manquante).');
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _savePresetWithPrompt(col),
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePresetWithPrompt(
    CollectionReference<Map<String, dynamic>> presetsCol,
  ) async {
    if (_busy) return;

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom du preset'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom',
            hintText: 'Ex: Waze sombre + glow',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    final presetName = (name ?? '').trim();
    if (presetName.isEmpty) return;

    setState(() => _busy = true);
    try {
      final cfg = _config.validated();
      final doc = presetsCol.doc();
      await doc.set({
        'name': presetName,
        'config': cfg.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('Preset enregistré');
    } catch (e) {
      _snack('Enregistrement preset échoué: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Style Wizard Pro'),
        actions: [
          IconButton(
            tooltip: 'Presets',
            onPressed: _busy ? null : _openPresetsDialog,
            icon: const Icon(Icons.bookmarks_outlined),
          ),
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
                    onPressed: (_busy || _loading)
                        ? null
                        : () => Navigator.of(context).pop('previous'),
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
                      backgroundColor: scheme.surface,
                      foregroundColor: scheme.onSurface,
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
                        : () => Navigator.of(context).pop('next'),
                    child: const Text('Suivant →'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
