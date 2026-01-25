// Stub implementation for non-web platforms
// Pas d'imports de dart:html/dart:js pour éviter les incompatibilités WebAssembly

void registerMapboxViewFactory(String viewType, dynamic Function(int) factory) {
  throw UnsupportedError('Cannot register view factory on non-web platform');
}
