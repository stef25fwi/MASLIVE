import 'dart:js_interop';

@JS('__MAPBOX_TOKEN__')
external JSString? _mapboxToken;

String readWebMapboxToken() {
  return _mapboxToken?.toDart.trim() ?? '';
}