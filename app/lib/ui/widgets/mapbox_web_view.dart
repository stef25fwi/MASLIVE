// Facade with conditional export.
// - Web: Mapbox GL JS via HtmlElementView (uses dart:html/js)
// - Non-web: harmless stub widget so mobile/desktop builds keep compiling.

export 'mapbox_web_view_widget_stub.dart'
    if (dart.library.html) 'mapbox_web_view_widget_web.dart';
