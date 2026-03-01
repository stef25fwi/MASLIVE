import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service abstrait pour contrôler le style des bâtiments 3D sur la carte Mapbox.
///
/// Permet de:
/// - Activer/désactiver les bâtiments 3D
/// - Régler leur transparence (opacity)
/// - Détecter si les bâtiments sont disponibles dans le style actuel
abstract class MapBuildingsStyleService {
  /// IDs de couches 3D à tenter (selon les styles Mapbox)
  static const List<String> possibleLayerIds = [
    '3d-buildings',
    'building-3d',
    'buildings-3d',
    'maslive-3d-buildings',
    'building',
  ];

  /// Définit l'opacité des bâtiments 3D (0.0 = invisible, 1.0 = opaque)
  ///
  /// Retourne `true` si l'opacité a pu être appliquée, `false` sinon.
  Future<bool> setBuildingsOpacity(double opacity);

  /// Récupère l'opacité actuelle des bâtiments 3D
  ///
  /// Retourne `null` si la couche n'existe pas ou n'est pas accessible.
  Future<double?> getBuildingsOpacity();

  /// Active ou désactive les bâtiments 3D
  ///
  /// Retourne `true` si le changement a pu être appliqué, `false` sinon.
  Future<bool> setBuildingsEnabled(bool enabled);

  /// Vérifie si les bâtiments 3D sont disponibles dans le style actuel
  Future<bool> is3DBuildingsAvailable();

  /// Trouve la première couche de type fill-extrusion dans le style
  ///
  /// Retourne l'ID de la couche trouvée, ou `null` si aucune n'existe.
  Future<String?> findBuildingLayer();

  /// Log un message de debug avec préfixe [BuildingsOpacity]
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[BuildingsOpacity] $message');
    }
  }

  /// Clamp une valeur d'opacité entre 0.0 et 1.0
  double _clampOpacity(double value) {
    return value.clamp(0.0, 1.0);
  }
}
