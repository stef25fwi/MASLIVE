// Web implementation
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

void registerMapboxViewFactory(String viewType, dynamic Function(int) factory) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, factory);
}
