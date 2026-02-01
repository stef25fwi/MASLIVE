// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

import 'package:flutter/material.dart';

/// Crée une HtmlElementView pour afficher la carte Mapbox sur le web
Widget webHtmlMapView(String divId) {
  const viewType = 'mapbox-gl-view';

  // On enregistre 1 fois par divId (viewType unique par div)
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory('$viewType-$divId', (int _) {
    final el = html.DivElement()
      ..id = divId
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = 'transparent';
    return el;
  });

  return HtmlElementView(viewType: '$viewType-$divId');
}

/// Appelle une méthode JavaScript sur le bridge Mapbox
void jsCallMapboxBridge(String method, [List<dynamic> args = const []]) {
  try {
    final context = js.context;
    // Essayer d'appeler window.method directement
    if (context.hasProperty(method)) {
      context.callMethod(method, args);
    } else {
      debugPrint('⚠️ Méthode JS $method introuvable');
    }
  } catch (e) {
    debugPrint('⚠️ Erreur JS call: $e');
  }
}

/// Vérifie si le bridge Mapbox est disponible
bool isMapboxBridgeAvailable() {
  try {
    return js.context.hasProperty('initMapboxMap');
  } catch (_) {
    return false;
  }
}
