/// Export conditionnel pour l'interop Mapbox Web
/// 
/// Ce fichier sélectionne automatiquement la bonne implémentation :
/// - Sur Web : utilise web_mapbox_gl_web_impl.dart (avec dart:html)
/// - Sur Mobile : utilise web_mapbox_gl_stub_impl.dart (implémentations vides)

export 'web_mapbox_gl_stub_impl.dart'
  if (dart.library.html) 'web_mapbox_gl_web_impl.dart';
