import 'dart:html' as html;

void triggerWebViewportResize() {
  // Mapbox GL JS listens to window resize; this forces a layout recompute.
  html.window.dispatchEvent(html.Event('resize'));
}
