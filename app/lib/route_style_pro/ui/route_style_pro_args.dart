// Arguments de navigation pour la page RouteStyleWizardPro.
// Fichier léger importé dans main.dart (pas de dépendance lourde).

import '../models/route_style_config.dart' show LatLng;

class RouteStyleProArgs {
  final String? projectId;
  final String? circuitId;
  final List<LatLng>? initialRoute;
  final String? initialStyleUrl;

  const RouteStyleProArgs({
    this.projectId,
    this.circuitId,
    this.initialRoute,
    this.initialStyleUrl,
  });
}
