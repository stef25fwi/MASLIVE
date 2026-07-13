from pathlib import Path

service_path = Path('app/lib/services/market_map_service.dart')
s = service_path.read_text()

insert_after = """class VisibleCircuitsIndex {
  const VisibleCircuitsIndex({
    required this.countryIds,
    required this.eventIdsByCountry,
  });

  final Set<String> countryIds;
  final Map<String, Set<String>> eventIdsByCountry;

  Set<String> eventIdsForCountry(String countryId) {
    return eventIdsByCountry[countryId] ?? const <String>{};
  }
}
"""
insert_block = """
class MarketMapCatalogSnapshot {
  const MarketMapCatalogSnapshot({
    required this.countries,
    required this.eventsByCountry,
    required this.circuitsByEvent,
    required this.visibleIndex,
  });

  final List<MarketCountry> countries;
  final Map<String, List<MarketEvent>> eventsByCountry;
  final Map<String, List<MarketCircuit>> circuitsByEvent;
  final VisibleCircuitsIndex visibleIndex;

  List<MarketEvent>? eventsForCountry(String countryId) {
    return eventsByCountry[countryId];
  }

  List<MarketCircuit>? circuitsForEvent({
    required String countryId,
    required String eventId,
  }) {
    return circuitsByEvent[_catalogEventKey(countryId, eventId)];
  }
}

String _catalogEventKey(String countryId, String eventId) {
  return '$countryId|$eventId';
}
"""
if insert_block not in s:
    if insert_after not in s:
        raise SystemExit('VisibleCircuitsIndex block not found')
    s = s.replace(insert_after, insert_after + insert_block, 1)

old_ctor = """  MarketMapService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _countriesCol =>
      _db.collection('marketMap');
"""
new_ctor = """  MarketMapService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  MarketMapCatalogSnapshot? _preloadedCatalog;
  Future<MarketMapCatalogSnapshot>? _preloadFuture;

  CollectionReference<Map<String, dynamic>> get _countriesCol =>
      _db.collection('marketMap');
"""
if new_ctor not in s:
    if old_ctor not in s:
        raise SystemExit('constructor block not found')
    s = s.replace(old_ctor, new_ctor, 1)

insert_after_circuit_visible = """  bool _circuitIsVisible(Map<String, dynamic> data) {
    return (data['isVisible'] as bool?) ?? (data['visible'] as bool?) ?? false;
  }
"""
preload_methods = """
  Stream<T> _withPreloadedValue<T>(T initialValue, Stream<T> liveStream) {
    late final StreamController<T> controller;
    StreamSubscription<T>? sub;

    controller = StreamController<T>(
      onListen: () {
        controller.add(initialValue);
        sub = liveStream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );

    return controller.stream;
  }

  MarketMapCatalogSnapshot? get preloadedSelectorCatalog => _preloadedCatalog;

  Future<MarketMapCatalogSnapshot> preloadSelectorCatalog({
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _preloadedCatalog;
      if (cached != null) return Future.value(cached);
      final running = _preloadFuture;
      if (running != null) return running;
    }

    final future = _loadSelectorCatalog();
    _preloadFuture = future;
    return future.whenComplete(() {
      if (identical(_preloadFuture, future)) {
        _preloadFuture = null;
      }
    });
  }

  Future<MarketMapCatalogSnapshot> _loadSelectorCatalog() async {
    final countriesSnap = await _countriesCol.orderBy('name').get();
    final countries = countriesSnap.docs.map(MarketCountry.fromDoc).toList();

    final eventsByCountry = <String, List<MarketEvent>>{};
    final circuitsByEvent = <String, List<MarketCircuit>>{};
    final visibleCountryIds = <String>{};
    final visibleEventIdsByCountry = <String, Set<String>>{};

    await Future.wait(
      countries.map((country) async {
        try {
          final eventsSnap = await _countriesCol
              .doc(country.id)
              .collection('events')
              .orderBy('startDate', descending: true)
              .orderBy('name')
              .get();
          final events = eventsSnap.docs
              .map((doc) => MarketEvent.fromDoc(doc, countryId: country.id))
              .toList();
          eventsByCountry[country.id] = events;

          await Future.wait(
            events.map((event) async {
              try {
                final circuitsSnap = await _countriesCol
                    .doc(country.id)
                    .collection('events')
                    .doc(event.id)
                    .collection('circuits')
                    .orderBy('updatedAt', descending: true)
                    .orderBy('name')
                    .get();
                final circuits = circuitsSnap.docs
                    .map((doc) => MarketCircuit.fromDoc(doc))
                    .toList();
                circuitsByEvent[_catalogEventKey(country.id, event.id)] =
                    circuits;

                final hasVisiblePublished = circuits.any(
                  (c) => c.isVisible == true && c.status == 'published',
                );
                if (hasVisiblePublished) {
                  visibleCountryIds.add(country.id);
                  (visibleEventIdsByCountry[country.id] ??= <String>{}).add(
                    event.id,
                  );
                }
              } on FirebaseException catch (error) {
                if (error.code == 'permission-denied') return;
                rethrow;
              }
            }),
          );
        } on FirebaseException catch (error) {
          if (error.code == 'permission-denied') return;
          rethrow;
        }
      }),
    );

    final snapshot = MarketMapCatalogSnapshot(
      countries: countries,
      eventsByCountry: eventsByCountry,
      circuitsByEvent: circuitsByEvent,
      visibleIndex: VisibleCircuitsIndex(
        countryIds: visibleCountryIds,
        eventIdsByCountry: visibleEventIdsByCountry,
      ),
    );
    _preloadedCatalog = snapshot;
    return snapshot;
  }
"""
if preload_methods not in s:
    if insert_after_circuit_visible not in s:
        raise SystemExit('circuit visible block not found')
    s = s.replace(insert_after_circuit_visible, insert_after_circuit_visible + preload_methods, 1)

old_return_index = """    return controller.stream;
  }

  VisibleCircuitsIndex _visibleIndexFromCircuitsGroupSnapshot(
"""
new_return_index = """    final cached = _preloadedCatalog?.visibleIndex;
    final live = controller.stream;
    return cached == null ? live : _withPreloadedValue(cached, live);
  }

  VisibleCircuitsIndex _visibleIndexFromCircuitsGroupSnapshot(
"""
if new_return_index not in s:
    if old_return_index not in s:
        raise SystemExit('watchVisibleCircuitsIndex return block not found')
    s = s.replace(old_return_index, new_return_index, 1)

old_countries = """  Stream<List<MarketCountry>> watchCountries() {
    return _countriesCol
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MarketCountry.fromDoc).toList());
  }
"""
new_countries = """  Stream<List<MarketCountry>> watchCountries() {
    final live = _countriesCol
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MarketCountry.fromDoc).toList());
    final cached = _preloadedCatalog?.countries;
    return cached == null ? live : _withPreloadedValue(cached, live);
  }
"""
if new_countries not in s:
    if old_countries not in s:
        raise SystemExit('watchCountries block not found')
    s = s.replace(old_countries, new_countries, 1)

old_events = """  Stream<List<MarketEvent>> watchEvents({required String countryId}) {
    return _countriesCol
        .doc(countryId)
        .collection('events')
        .orderBy('startDate', descending: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MarketEvent.fromDoc(doc, countryId: countryId))
              .toList(),
        );
  }
"""
new_events = """  Stream<List<MarketEvent>> watchEvents({required String countryId}) {
    final live = _countriesCol
        .doc(countryId)
        .collection('events')
        .orderBy('startDate', descending: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MarketEvent.fromDoc(doc, countryId: countryId))
              .toList(),
        );
    final cached = _preloadedCatalog?.eventsForCountry(countryId);
    return cached == null ? live : _withPreloadedValue(cached, live);
  }
"""
if new_events not in s:
    if old_events not in s:
        raise SystemExit('watchEvents block not found')
    s = s.replace(old_events, new_events, 1)

old_circuits = """  Stream<List<MarketCircuit>> watchCircuits({
    required String countryId,
    required String eventId,
  }) {
    return _countriesCol
        .doc(countryId)
        .collection('events')
        .doc(eventId)
        .collection('circuits')
        .orderBy('updatedAt', descending: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MarketCircuit.fromDoc(doc)).toList(),
        );
  }
"""
new_circuits = """  Stream<List<MarketCircuit>> watchCircuits({
    required String countryId,
    required String eventId,
  }) {
    final live = _countriesCol
        .doc(countryId)
        .collection('events')
        .doc(eventId)
        .collection('circuits')
        .orderBy('updatedAt', descending: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MarketCircuit.fromDoc(doc)).toList(),
        );
    final cached = _preloadedCatalog?.circuitsForEvent(
      countryId: countryId,
      eventId: eventId,
    );
    return cached == null ? live : _withPreloadedValue(cached, live);
  }
"""
if new_circuits not in s:
    if old_circuits not in s:
        raise SystemExit('watchCircuits block not found')
    s = s.replace(old_circuits, new_circuits, 1)

service_path.write_text(s)

page_path = Path('app/lib/pages/default_map_page.dart')
p = page_path.read_text()

insert_after_get_service = """  MarketMapService _getMarketMapService() {
    return _marketMapService ??= MarketMapService();
  }
"""
preload_page_method = """

  Future<void> _preloadMapMarketSelectorCatalog() async {
    try {
      await _getMarketMapService().preloadSelectorCatalog();
      if (kDebugMode) {
        debugPrint('✅ MapMarket selector catalog preloaded');
      }
    } catch (error) {
      debugPrint('⚠️ MapMarket selector preload failed: $error');
    }
  }
"""
if preload_page_method not in p:
    if insert_after_get_service not in p:
        raise SystemExit('get MarketMapService block not found')
    p = p.replace(insert_after_get_service, insert_after_get_service + preload_page_method, 1)

old_init_line = """    unawaited(_restoreLastHomeStyleUrl());

    _isTracking = _geo.isTracking;
"""
new_init_line = """    unawaited(_restoreLastHomeStyleUrl());
    unawaited(_preloadMapMarketSelectorCatalog());

    _isTracking = _geo.isTracking;
"""
if new_init_line not in p:
    if old_init_line not in p:
        raise SystemExit('initState restore style block not found')
    p = p.replace(old_init_line, new_init_line, 1)

page_path.write_text(p)
