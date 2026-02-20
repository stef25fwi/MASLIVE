import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/draft_circuit.dart';

class WizardCircuitProvider extends ChangeNotifier {
  DraftCircuit _draft = DraftCircuit.empty();

  DraftCircuit get draft => _draft;

  void setStep1Fields({
    required String countryId,
    required String countryName,
    required String eventName,
    required String circuitName,
    required DateTime date,
    required String? countryIso2,
  }) {
    _draft = _draft.copyWith(
      countryId: countryId,
      countryName: countryName,
      eventName: eventName,
      circuitName: circuitName,
      date: date,
      countryIso2: countryIso2,
    );
    notifyListeners();
  }

  void setPerimeter(DraftPerimeter perimeter) {
    _draft = _draft.copyWith(perimeter: perimeter);
    notifyListeners();
  }

  void addRoutePoint(Point p) {
    final r = _draft.route;
    _draft = _draft.copyWith(route: r.copyWith(routePoints: [...r.routePoints, p]));
    notifyListeners();
  }

  void setRoutePoints(List<Point> points) {
    final r = _draft.route;
    _draft = _draft.copyWith(route: r.copyWith(routePoints: points));
    notifyListeners();
  }

  void removeRoutePointAt(int index) {
    final r = _draft.route;
    final pts = [...r.routePoints]..removeAt(index);
    _draft = _draft.copyWith(route: r.copyWith(routePoints: pts));
    notifyListeners();
  }

  void setRouteConnected(bool connected) {
    final r = _draft.route;
    _draft = _draft.copyWith(route: r.copyWith(connected: connected));
    notifyListeners();
  }

  void setRouteMode(RouteMode mode) {
    final r = _draft.route;
    _draft = _draft.copyWith(route: r.copyWith(mode: mode));
    notifyListeners();
  }

  void setRouteGeometry(List<Point> geometry) {
    final r = _draft.route;
    _draft = _draft.copyWith(route: r.copyWith(routeGeometry: geometry));
    notifyListeners();
  }

  void clearRouteGeometry() {
    final r = _draft.route;
    _draft = _draft.copyWith(route: r.copyWith(routeGeometry: []));
    notifyListeners();
  }
}
