import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/market_circuit_models.dart';
import '../models/market_country.dart';
import '../services/market_map_service.dart';
import '../services/mapbox_token_service.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';
import 'circuit_wizard_pro_page.dart';

String _iso2ToFlagEmoji(String iso2) {
  final code = iso2.trim().toUpperCase();
  if (code.length != 2) return '🏳️';
  const base = 0x1F1E6;
  final first = base + (code.codeUnitAt(0) - 65);
  final second = base + (code.codeUnitAt(1) - 65);
  return String.fromCharCode(first) + String.fromCharCode(second);
}

class CircuitWizardEntryPage extends StatefulWidget {
  const CircuitWizardEntryPage({super.key});

  @override
  State<CircuitWizardEntryPage> createState() => _CircuitWizardEntryPageState();
}

class _CircuitWizardEntryPageState extends State<CircuitWizardEntryPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Création de Circuits'), elevation: 0),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.blue.withValues(alpha: 0.05),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '🗺️ Wizard Circuit Pro',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Créez des circuits professionnels avec périmètre, tracé, POI et validation automatique',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _createNewProject,
                  icon: const Icon(Icons.add_circle),
                  label: const Text('+ Nouveau Circuit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Projets en cours (brouillons)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('map_projects')
                  .where('uid', isEqualTo: _auth.currentUser?.uid ?? '')
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Erreur: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final projects =
                    snapshot.data?.docs
                        .map((doc) => CircuitProject.fromFirestore(doc))
                        .toList() ??
                    [];

                if (projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun circuit',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Créez votre premier circuit en cliquant ci-dessus',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _buildProjectCard(project);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(CircuitProject project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: project.status == 'published'
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            project.status == 'published' ? Icons.check_circle : Icons.edit,
            color: project.status == 'published' ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          project.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${project.countryId} • ${project.eventId}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    project.status == 'published' ? '✅ Publié' : '✏️ Brouillon',
                  ),
                  backgroundColor: project.status == 'published'
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    color: project.status == 'published'
                        ? Colors.green
                        : Colors.orange,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (project.perimeter.isNotEmpty)
                  Chip(
                    label: Text('${project.perimeter.length} pts périm.'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (project.route.isNotEmpty)
                  Chip(
                    label: Text('${project.route.length} pts tracé'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (ctx) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Continuer'),
                ],
              ),
              onTap: () => _openProject(project.id),
            ),
            if (project.status != 'published')
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onTap: () => _deleteProject(project.id),
              ),
          ],
        ),
        onTap: () => _openProject(project.id),
      ),
    );
  }

  Future<void> _createNewProject() async {
    final input = await showDialog<_NewCircuitInput>(
      context: context,
      builder: (ctx) => _NewCircuitInputDialog(),
    );

    if (input == null || !mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté.')),
      );
      return;
    }

    try {
      final countryId = input.countryId.trim();
      final eventId = input.eventId.trim();

      // Contexte utilisateur (groupId) requis par les règles map_projects.
      String groupId = 'default';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final data = userDoc.data() ?? const <String, dynamic>{};
        final g = (data['groupId'] as String?)?.trim() ?? '';
        if (g.isNotEmpty) groupId = g;
      } catch (_) {
        // ignore (fallback = default)
      }

      const defaultRouteStyle = <String, dynamic>{
        'color': '#1A73E8',
        'width': 6.0,
        'roadLike': true,
        'shadow3d': true,
        'showDirection': true,
        'animateDirection': false,
        'animationSpeed': 1.0,
      };

      // Si l'utilisateur saisit un événement (editable), on s'assure que le doc existe.
      // (Sinon le wizard pro ne pourra pas charger les streams marketMap.)
      if (countryId.isNotEmpty && eventId.isNotEmpty) {
        final eventRef = _firestore
            .collection('marketMap')
            .doc(countryId)
            .collection('events')
            .doc(eventId);
        final snap = await eventRef.get();
        if (!snap.exists) {
          final eventName = input.eventName.trim().isEmpty
              ? eventId
              : input.eventName.trim();
          await eventRef.set({
            'name': eventName,
            'slug': eventId,
            'countryId': countryId,
            'startDate': Timestamp.fromDate(input.startDate),
            'endDate': Timestamp.fromDate(input.endDate),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      final ref = _firestore.collection('map_projects').doc();
      await ref.set({
        // Champs imposés par les règles (validProjectPayloadCreate)
        'uid': user.uid,
        'createdBy': user.uid,
        'groupId': groupId,
        'sourceOfTruth': 'map_projects',
        'status': 'draft',
        'version': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // Source de vérité pour le wizard
        'current': {
          'name': input.name.trim(),
          'countryId': countryId,
          'eventId': eventId,
          'description': '',
          'styleUrl': '',
          'perimeter': <dynamic>[],
          'route': <dynamic>[],
          'routeStyle': defaultRouteStyle,
        },

        // Compat legacy (facultatif mais utile pour le listing/anciens écrans)
        'name': input.name.trim(),
        'countryId': countryId,
        'countryName': input.countryName,
        'countryIso2': input.countryIso2,
        'eventId': eventId,
        'eventName': input.eventName,
        // Compat: eventDate reste la date de début.
        'eventDate': Timestamp.fromDate(input.startDate),
        'eventEndDate': Timestamp.fromDate(input.endDate),
        'description': '',
        'styleUrl': '',
        'perimeter': <dynamic>[],
        'route': <dynamic>[],
        'routeStyle': defaultRouteStyle,
      });

      if (!mounted) return;
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CircuitWizardProPage(projectId: ref.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
    }
  }

  void _openProject(String projectId) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CircuitWizardProPage(projectId: projectId),
      ),
    );
  }

  Future<void> _deleteProject(String projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce circuit ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('map_projects').doc(projectId).delete();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('✅ Circuit supprimé')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
        }
      }
    }
  }
}

class _NewCircuitInput {
  final String countryId;
  final String countryName;
  final String? countryIso2;
  final String eventId;
  final String eventName;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  const _NewCircuitInput({
    required this.countryId,
    required this.countryName,
    required this.countryIso2,
    required this.eventId,
    required this.eventName,
    required this.name,
    required this.startDate,
    required this.endDate,
  });
}

class _NewCircuitInputDialog extends StatefulWidget {
  const _NewCircuitInputDialog();

  @override
  State<_NewCircuitInputDialog> createState() => _NewCircuitInputDialogState();
}

class _NewCircuitInputDialogState extends State<_NewCircuitInputDialog> {
  final MarketMapService _marketMapService = MarketMapService();

  final MasLiveMapController _previewMapController = MasLiveMapController();
  bool _previewMapReady = false;
  int _previewMapFocusSeq = 0;

  final _countryController = TextEditingController();
  final _eventController = TextEditingController();
  final _nameController = TextEditingController();

  MarketCountry? _selectedCountry;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _usePeriod = false;
  String _countryQuery = '';

  @override
  void dispose() {
    _countryController.dispose();
    _eventController.dispose();
    _nameController.dispose();
    _previewMapController.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _countryController.text.trim().isNotEmpty &&
        _eventController.text.trim().isNotEmpty &&
        _nameController.text.trim().isNotEmpty;
  }

  String _eventName() => _eventController.text.trim();

  String _eventId() {
    final name = _eventName();
    if (name.isEmpty) return '';
    final base = MarketMapService.slugify(name);
    if (base.isEmpty) return '';

    final yyyy = _startDate.year.toString().padLeft(4, '0');
    final mm = _startDate.month.toString().padLeft(2, '0');
    final dd = _startDate.day.toString().padLeft(2, '0');
    return MarketMapService.slugify('$base-$yyyy$mm$dd');
  }

  String _countryLabel(MarketCountry c) {
    final name = c.name.trim().isEmpty ? c.id : c.name.trim();
    return name;
  }

  String _countryCodeFor(MarketCountry c) {
    final id = c.id.trim();
    if (id.length == 2) return id.toUpperCase();

    final slug = c.slug.trim().toLowerCase();
    final name = c.name.trim().toLowerCase();
    const known = <String, String>{
      'guadeloupe': 'GP',
      'martinique': 'MQ',
      'guyane': 'GF',
      'reunion': 'RE',
      'réunion': 'RE',
      'saint-martin': 'MF',
      'saint martin': 'MF',
    };

    return known[slug] ?? known[name] ?? '';
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatRange(DateTime start, DateTime end) {
    return '${_formatDate(start)} → ${_formatDate(end)}';
  }

  ({double lng, double lat, double zoom}) _countryPreviewCamera(
    MarketCountry? country,
  ) {
    if (country == null) {
      return (lng: -61.533, lat: 16.241, zoom: 5.0);
    }

    final iso2 = _countryCodeFor(country);
    switch (iso2) {
      case 'GP':
        return (lng: -61.551, lat: 16.265, zoom: 9.5);
      case 'MQ':
        return (lng: -61.02, lat: 14.641, zoom: 9.5);
      case 'GF':
        return (lng: -53.125, lat: 3.934, zoom: 7.0);
      case 'RE':
        return (lng: 55.536, lat: -21.115, zoom: 9.0);
      case 'MF':
        return (lng: -63.073, lat: 18.071, zoom: 11.0);
      case 'FR':
        return (lng: 2.213, lat: 46.227, zoom: 5.0);
      default:
        return (lng: -61.533, lat: 16.241, zoom: 5.0);
    }
  }

  Future<({double lng, double lat})?> _geocodeCountryCenter(
    String countryName,
  ) async {
    final token = await MapboxTokenService.getToken();
    if (token.trim().isEmpty) return null;

    final q = countryName.trim();
    if (q.isEmpty) return null;

    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json',
      {
        'access_token': token,
        'types': 'country',
        'limit': '1',
      },
    );

    final resp = await http.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;

    final json = jsonDecode(resp.body);
    if (json is! Map<String, dynamic>) return null;
    final features = json['features'];
    if (features is! List || features.isEmpty) return null;
    final first = features.first;
    if (first is! Map) return null;
    final center = first['center'];
    if (center is! List || center.length < 2) return null;
    final lng = center[0];
    final lat = center[1];
    if (lng is! num || lat is! num) return null;
    return (lng: lng.toDouble(), lat: lat.toDouble());
  }

  Future<void> _focusPreviewMapOnCountry(MarketCountry country) async {
    if (!_previewMapReady) return;

    final seq = ++_previewMapFocusSeq;
    final cam = _countryPreviewCamera(country);
    await _previewMapController.moveTo(
      lng: cam.lng,
      lat: cam.lat,
      zoom: cam.zoom,
      animate: false,
    );

    // Si on n'a pas de mapping connu (fallback), on tente un centrage via géocodage.
    final iso2 = _countryCodeFor(country);
    final hasKnownIso2 = iso2 == 'GP' ||
        iso2 == 'MQ' ||
        iso2 == 'GF' ||
        iso2 == 'RE' ||
        iso2 == 'MF' ||
        iso2 == 'FR';

    if (hasKnownIso2) return;

    try {
      final geocoded = await _geocodeCountryCenter(_countryLabel(country));
      if (!mounted) return;
      if (seq != _previewMapFocusSeq) return;
      if (geocoded == null) return;

      await _previewMapController.moveTo(
        lng: geocoded.lng,
        lat: geocoded.lat,
        zoom: 5.0,
        animate: false,
      );
    } catch (_) {
      // Best-effort: si le géocodage échoue, on garde le fallback.
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      _endDate = _startDate;
    });
  }

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
  }

  MarketCountry? _resolveCountry(List<MarketCountry> countries) {
    if (_selectedCountry != null) return _selectedCountry;

    final raw = _countryController.text.trim();
    if (raw.isEmpty) return null;

    final needle = MarketMapService.slugify(raw);
    if (needle.isEmpty) return null;

    for (final c in countries) {
      final label = _countryLabel(c);
      final labelSlug = MarketMapService.slugify(label);
      if (labelSlug == needle) return c;

      final idSlug = MarketMapService.slugify(c.id);
      if (idSlug == needle) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final availableWidth = (screen.width - 32).clamp(0.0, double.infinity);
    final dialogWidth = availableWidth > 900 ? 900.0 : availableWidth;
    final dialogMaxHeight = screen.height * 0.9;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogMaxHeight),
        child: SizedBox(
          width: dialogWidth,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<List<MarketCountry>>(
              stream: _marketMapService.watchCountries(),
              builder: (context, snapshot) {
              final countries = snapshot.data ?? const <MarketCountry>[];
              final q = MarketMapService.slugify(_countryQuery);
              final filtered = countries
                  .where((c) {
                    if (q.isEmpty) return true;
                    final label = _countryLabel(c);
                    final labelSlug = MarketMapService.slugify(label);
                    return labelSlug.contains(q);
                  })
                  .toList()
                ..sort((a, b) => _countryLabel(a).compareTo(_countryLabel(b)));

              final resolvedCountry = _resolveCountry(countries);
              final cam = _countryPreviewCamera(resolvedCountry);

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Nouveau circuit',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _countryController,
                    decoration: InputDecoration(
                      labelText: 'Pays',
                      hintText: 'Rechercher un pays…',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            resolvedCountry == null
                                ? '🏳️'
                                : _iso2ToFlagEmoji(_countryCodeFor(resolvedCountry)),
                          ),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _countryQuery = value;
                        _selectedCountry = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: MasLiveMap(
                          controller: _previewMapController,
                          initialLng: cam.lng,
                          initialLat: cam.lat,
                          initialZoom: cam.zoom,
                          styleUrl: null,
                          onTap: null,
                          onMapReady: (c) async {
                            _previewMapReady = true;
                            // recentrer après ready pour refléter le pays sélectionné
                            await c.moveTo(
                              lng: cam.lng,
                              lat: cam.lat,
                              zoom: cam.zoom,
                              animate: false,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun pays trouvé',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              final iso2 = _countryCodeFor(c);
                              return ListTile(
                                dense: true,
                                leading: Text(
                                  _iso2ToFlagEmoji(iso2),
                                  style: const TextStyle(fontSize: 18),
                                ),
                                title: Text(_countryLabel(c)),
                                subtitle: iso2.isEmpty ? null : Text(iso2),
                                onTap: () {
                                  setState(() {
                                    _selectedCountry = c;
                                    _countryController.text = _countryLabel(c);
                                    _countryQuery = _countryLabel(c);
                                  });

                                  unawaited(_focusPreviewMapOnCountry(c));
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _eventController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Événement',
                      hintText: 'Ex: Carnaval, Festival…',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nom du circuit',
                      hintText: 'Ex: Défilé Centre-ville…',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Date'),
                          selected: !_usePeriod,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() {
                              _usePeriod = false;
                              _endDate = _startDate;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Période'),
                          selected: _usePeriod,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() {
                              _usePeriod = true;
                              if (_endDate.isBefore(_startDate)) {
                                _endDate = _startDate;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            _usePeriod
                                ? 'Période : ${_formatRange(_startDate, _endDate)}'
                                : 'Date : ${_formatDate(_startDate)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _usePeriod ? _pickPeriod : _pickDate,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Choisir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: !_isValid
                          ? null
                          : () {
                              final country = resolvedCountry;
                              if (country == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sélectionnez un pays.'),
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(
                                context,
                                _NewCircuitInput(
                                  countryId: country.id.trim(),
                                  countryName: _countryLabel(country),
                                  countryIso2: _countryCodeFor(country),
                                  eventId: _eventId(),
                                  eventName: _eventName(),
                                  name: _nameController.text.trim(),
                                  startDate: _startDate,
                                  endDate: _endDate,
                                ),
                              );
                            },
                      child: const Text('Continuer'),
                    ),
                  ),
                  ],
                ),
              );
              },
            ),
          ),
        ),
      ),
    );
  }
}
