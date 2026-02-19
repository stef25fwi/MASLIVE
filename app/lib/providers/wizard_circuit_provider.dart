import 'package:flutter/foundation.dart';

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
}
