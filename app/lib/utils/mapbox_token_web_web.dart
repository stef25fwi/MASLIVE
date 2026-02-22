import 'dart:js_interop';

@JS('__MAPBOX_TOKEN__')
external JSString? get _mapboxToken;

@JS('__MAPBOX_TOKEN__')
external set _mapboxToken(JSString? v);

String readWebMapboxToken() {
  return _mapboxToken?.toDart.trim() ?? '';
}

void writeWebMapboxToken(String token) {
  _mapboxToken = token.trim().toJS;
}

void clearWebMapboxToken() {
  _mapboxToken = ''.toJS;
}