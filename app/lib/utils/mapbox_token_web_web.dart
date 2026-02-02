import 'dart:js' as js;

String readWebMapboxToken() {
  final token = js.context['__MAPBOX_TOKEN__'];
  if (token == null) return '';
  if (token is String) return token.trim();
  return token.toString().trim();
}