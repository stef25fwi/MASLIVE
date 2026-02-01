import 'package:flutter/widgets.dart';

/// Stub pour les plateformes non-web (iOS, Android)
/// Retourne des implémentations vides au lieu de lancer des exceptions
Widget webHtmlMapView(String divId) => const SizedBox.shrink();

/// Stub pour appeler le bridge JavaScript (ne fait rien sur mobile)
void jsCallMapboxBridge(String method, List<dynamic> args) {}

/// Vérifie si le bridge Mapbox est disponible (toujours false sur mobile)
bool isMapboxBridgeAvailable() => false;
