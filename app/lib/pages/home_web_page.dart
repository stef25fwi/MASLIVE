import 'package:flutter/material.dart';

import '../services/mapbox_token_service.dart';
import '../ui/map/maslive_map.dart';

/// Page Web qui affiche la carte Mapbox en plein écran
class HomeWebPage extends StatelessWidget {
  const HomeWebPage({super.key});

  @override
  Widget build(BuildContext context) {
    final token = MapboxTokenService.getTokenSync();

    if (token.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Token Mapbox manquant.\n'
              'Configure MAPBOX_ACCESS_TOKEN (ou MAPBOX_TOKEN legacy)\n'
              'ou renseigne-le via la UI (SharedPreferences).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        color: Colors.grey[200],
        child: const MasLiveMap(
          initialLat: 16.2410,
          initialLng: -61.5340,
          initialZoom: 15.0,
          initialPitch: 45.0,
          initialBearing: 0.0,
          styleUrl: 'mapbox://styles/mapbox/streets-v12',
        ),
      ),
    );
  }
}
