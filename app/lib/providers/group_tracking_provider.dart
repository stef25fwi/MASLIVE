import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/group_tracking_service.dart';
import '../services/mapbox_polyline_snap_service.dart';

typedef TrackCoord = ({double lat, double lng});

class GroupTrackingProvider extends ChangeNotifier {
  GroupTrackingProvider({
    GroupTrackingService? service,
    MapboxPolylineSnapService? snapService,
  })  : _service = service ?? GroupTrackingService(),
        _snapService = snapService ?? MapboxPolylineSnapService();

  final GroupTrackingService _service;
  final MapboxPolylineSnapService _snapService;

  StreamSubscription<GpsSample>? _sub;
  Timer? _snapDebounce;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  Object? _lastError;
  Object? get lastError => _lastError;

  final List<TrackCoord> _raw = <TrackCoord>[];
  final List<TrackCoord> _snapped = <TrackCoord>[];

  List<TrackCoord> get rawPolyline => List.unmodifiable(_raw);
  List<TrackCoord> get snappedPolyline => List.unmodifiable(_snapped);

  TrackCoord? _lastPos;
  TrackCoord? get lastPos => _lastPos;

  Future<void> start({
    required String projectId,
    required String groupId,
    required String roleInGroup,
    required GpsStreamProvider gps,
    Duration minInterval = const Duration(seconds: 3),
    Duration ttl = const Duration(seconds: 120),
  }) async {
    _lastError = null;

    await stop(projectId: projectId);

    _raw.clear();
    _snapped.clear();
    _lastPos = null;

    _isTracking = true;
    notifyListeners();

    try {
      await _service.startTracking(
        projectId: projectId,
        groupId: groupId,
        roleInGroup: roleInGroup,
        gps: gps,
        minInterval: minInterval,
        ttl: ttl,
      );

      await _sub?.cancel();
      _sub = _service.samples.listen(_onSample);
    } catch (e) {
      _lastError = e;
      _isTracking = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop({required String projectId}) async {
    _snapDebounce?.cancel();
    _snapDebounce = null;

    await _sub?.cancel();
    _sub = null;

    if (_isTracking) {
      await _service.stopTracking(projectId: projectId);
    }

    _isTracking = false;
    notifyListeners();
  }

  void _onSample(GpsSample s) {
    final p = (lat: s.lat, lng: s.lng);
    _lastPos = p;

    if (_raw.isEmpty) {
      _raw.add(p);
    } else {
      final last = _raw.last;
      // Filtre "pas de changement" (ultra-simple)
      if ((last.lat - p.lat).abs() > 1e-7 || (last.lng - p.lng).abs() > 1e-7) {
        _raw.add(p);
      }
    }

    _scheduleSnap();
    notifyListeners();
  }

  void _scheduleSnap() {
    _snapDebounce?.cancel();
    _snapDebounce = Timer(const Duration(seconds: 1), () async {
      try {
        final snapped = await _snapService.snapPolyline(_raw);
        _snapped
          ..clear()
          ..addAll(snapped);
        notifyListeners();
      } catch (e) {
        // Snap best-effort: on ne bloque pas le tracking
        _lastError = e;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _snapDebounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
