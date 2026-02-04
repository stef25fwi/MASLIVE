import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Crée une HtmlElementView pour afficher la carte Mapbox sur le web
Widget webHtmlMapView(String divId) {
  const viewType = 'mapbox-gl-view';

  // On enregistre 1 fois par divId (viewType unique par div)
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory('$viewType-$divId', (int _) {
    final el = web.document.createElement('div') as web.HTMLDivElement
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
  // Ancienne API basée sur dart:js/dart:html.
  // Désormais, on utilise des bindings explicites (MasliveMapboxV2) ailleurs.
  debugPrint('⚠️ jsCallMapboxBridge($method, args:${args.length}) non supporté (interop WASM-friendly).');
}

/// Vérifie si le bridge Mapbox est disponible
bool isMapboxBridgeAvailable() {
  // Conservateur: sans dart:js, on ne sonde plus la présence de fonctions globales.
  // Les widgets/contrôleurs Mapbox Web doivent gérer l'init via MasliveMapboxV2.
  return false;
}
