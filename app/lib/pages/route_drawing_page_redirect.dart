import 'package:flutter/material.dart';
import 'legacy_stubs/route_drawing_page_legacy_stub.dart';

/// DEPRECATED: Utiliser RouteDrawingPageLegacy ou RouteDisplayMapboxPage
/// Ce fichier est conservé uniquement pour compatibilité, redirige vers legacy
@Deprecated('Utiliser RouteDrawingPageLegacy pour édition ou RouteDisplayMapboxPage pour affichage')
class RouteDrawingPage extends StatelessWidget {
  const RouteDrawingPage({super.key, this.groupId});

  final String? groupId;

  @override
  Widget build(BuildContext context) {
    // Redirection automatique vers la version legacy (flutter_map interactive)
    return RouteDrawingPageLegacy(groupId: groupId);
  }
}
