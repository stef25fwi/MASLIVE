import 'package:web/web.dart' as web;

void triggerWebViewportResize() {
  // Mapbox GL JS listens to window resize; this forces a layout recompute.
  web.window.dispatchEvent(web.Event('resize'));
}
