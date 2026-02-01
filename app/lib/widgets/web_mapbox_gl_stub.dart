import 'package:flutter/widgets.dart';

/// Stub pour les plateformes non-web (iOS, Android)
/// Ces fonctions ne seront jamais appelées sur mobile
Widget webHtmlMapView(String divId) {
  throw UnimplementedError(
    'webHtmlMapView() is only available on web platform',
  );
}

/// Stub pour appeler le bridge JavaScript (non disponible sur mobile)
void jsCallMapboxBridge(String method, List<dynamic> args) {
  throw UnimplementedError(
    'jsCallMapboxBridge() is only available on web platform',
  );
}

/// Vérifie si le bridge Mapbox est disponible (toujours false sur mobile)
bool isMapboxBridgeAvailable() {
  return false;
}
