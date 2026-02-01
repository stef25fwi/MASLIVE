/// Export conditionnel pour l'interop Mapbox Web
/// 
/// Ce fichier sélectionne automatiquement la bonne implémentation :
/// - Sur Web : utilise web_mapbox_gl_web_impl.dart (avec dart:html)
/// - Sur Mobile : utilise web_mapbox_gl_stub_impl.dart (implémentations vides)
/// 
/// Usage dans votre code :
/// ```dart
/// import 'web_mapbox_gl_interop.dart';
/// 
/// if (isMapboxBridgeAvailable()) {
///   jsCallMapboxBridge('flyToPosition', [-61.5, 16.2, 15.0]);
/// }
/// ```

export 'web_mapbox_gl_stub_impl.dart'
    if (dart.library.html) 'web_mapbox_gl_web_impl.dart';
