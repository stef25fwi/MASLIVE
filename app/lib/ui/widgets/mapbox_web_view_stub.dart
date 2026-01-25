// Stub implementation for non-web platforms
import 'dart:html' as html show Element;

void registerMapboxViewFactory(String viewType, html.Element Function(int) factory) {
  throw UnsupportedError('Cannot register view factory on non-web platform');
}
