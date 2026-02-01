import 'package:flutter/material.dart';

import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';

/// Page Web qui affiche la carte Mapbox en plein écran
class HomeWebPage extends StatefulWidget {
  const HomeWebPage({super.key});

  @override
  State<HomeWebPage> createState() => _HomeWebPageState();
}

class _HomeWebPageState extends State<HomeWebPage>
    with WidgetsBindingObserver {
  Size? _lastWebMapSize;
  int _webMapRebuildTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);

      _lastWebMapSize ??= size;
      if (size != _lastWebMapSize) {
        debugPrint(
          '🔄 HomeWebPage: Changement de taille détecté: '
          '${_lastWebMapSize?.width}x${_lastWebMapSize?.height} → '
          '${size.width}x${size.height}',
        );
        _lastWebMapSize = size;
        setState(() {
          _webMapRebuildTick++;
        });
      }
    });
  }

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

    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: size.width,
        height: size.height,
        color: Colors.grey[200],
        child: MapboxWebView(
          key: ValueKey(
            'mapbox-web-home-${_webMapRebuildTick}-${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
          ),
          accessToken: token,
          initialLat: 16.2410,
          initialLng: -61.5340,
          initialZoom: 15.0,
          initialPitch: 45.0,
          initialBearing: 0.0,
          styleUrl: 'mapbox://styles/mapbox/streets-v12',
          onMapReady: () {
            debugPrint('✅ Carte Web prête');
          },
        ),
      ),
    );
  }
}
