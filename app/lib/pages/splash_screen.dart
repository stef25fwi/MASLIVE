import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.assetPath = 'assets/splash/maslive.png',
    this.starCount = 140,
    this.luminanceThreshold = 0.62, // + haut = uniquement très lumineux
  });

  final String assetPath;
  final int starCount;
  final double luminanceThreshold;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _Star {
  _Star({
    required this.pos,
    required this.baseRadius,
    required this.phase,
    required this.speed,
    required this.twinklePower,
  });

  final Offset pos; // en coordonnées 0..1 (relatives)
  final double baseRadius;
  double phase;
  final double speed;
  final double twinklePower;
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  ui.Image? _img;
  ByteData? _rgba;
  final _rng = Random();
  final List<_Star> _stars = [];
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();

    // ✅ Force la barre de statut et navigation en noir
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(() {
        // tick "manuel" (pas besoin d'un Animation<double> dédié)
        for (final s in _stars) {
          s.phase += s.speed * 0.016; // ~60fps
        }
        if (mounted) setState(() {});
      });

    _loadImageAndSeedStars();

    // ✅ Navigation vers HomePage après 3 secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadImageAndSeedStars() async {
    final data = await rootBundle.load(widget.assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      // On downscale un peu pour accélérer le scan luminance
      targetWidth: 720,
    );
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final rgba = await img.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (!mounted) return;

    setState(() {
      _img = img;
      _rgba = rgba;
    });

    _seedStarsFromBrightPixels();
    _ticker.repeat();
  }

  void _seedStarsFromBrightPixels() {
    final img = _img;
    final rgba = _rgba;
    if (img == null || rgba == null) return;

    final w = img.width;
    final h = img.height;
    final bytes = rgba.buffer.asUint8List();

    // 1) Collecte de points candidats (zones lumineuses)
    final candidates = <Offset>[];
    final step = 2; // scan 1 pixel sur 2 (perf)
    for (int y = 0; y < h; y += step) {
      for (int x = 0; x < w; x += step) {
        final i = (y * w + x) * 4;
        final r = bytes[i] / 255.0;
        final g = bytes[i + 1] / 255.0;
        final b = bytes[i + 2] / 255.0;

        // Luminance perceptuelle
        final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;

        if (lum >= widget.luminanceThreshold) {
          candidates.add(Offset(x / w, y / h));
        }
      }
    }

    // Fallback si seuil trop haut
    if (candidates.isEmpty) {
      for (int i = 0; i < 6000; i++) {
        candidates.add(Offset(_rng.nextDouble(), _rng.nextDouble()));
      }
    }

    // 2) Tirage aléatoire de starCount points
    _stars.clear();
    for (int i = 0; i < widget.starCount; i++) {
      final p = candidates[_rng.nextInt(candidates.length)];
      _stars.add(
        _Star(
          pos: p,
          baseRadius: 0.7 + _rng.nextDouble() * 1.9,
          phase: _rng.nextDouble() * pi * 2,
          speed: 0.6 + _rng.nextDouble() * 1.8,
          twinklePower: 0.55 + _rng.nextDouble() * 0.9,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // ✅ fond noir
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ Image plein écran sans marge (cover)
          Image.asset(
            widget.assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),

          // ✅ Scintillement au-dessus
          IgnorePointer(
            child: CustomPaint(
              painter: _TwinklePainter(stars: _stars),
            ),
          ),
        ],
      ),
    );
  }
}

class _TwinklePainter extends CustomPainter {
  _TwinklePainter({required this.stars});

  final List<_Star> stars;

  @override
  void paint(Canvas canvas, Size size) {
    if (stars.isEmpty) return;

    // Glow "étoile"
    final glowPaint = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final corePaint = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);

    for (final s in stars) {
      // Twinkle : sin -> 0..1
      final t = (sin(s.phase) * 0.5 + 0.5);
      final alpha = (0.10 + t * 0.90) * s.twinklePower;

      final p = Offset(s.pos.dx * size.width, s.pos.dy * size.height);

      // Taille variable
      final r = s.baseRadius * (0.65 + t * 1.35);

      // Couleur "étoile" (blanc chaud)
      final c = Color.fromRGBO(255, 235, 200, alpha.clamp(0.0, 1.0));

      glowPaint.color = c.withOpacity((alpha * 0.55).clamp(0.0, 1.0));
      corePaint.color = c.withOpacity(alpha.clamp(0.0, 1.0));

      // Glow circulaire
      canvas.drawCircle(p, r * 2.2, glowPaint);

      // Étoile en croix (4 branches)
      _drawStarCross(canvas, p, r * 2.6, corePaint);
    }
  }

  void _drawStarCross(Canvas canvas, Offset c, double len, Paint paint) {
    final dx = Offset(len, 0);
    final dy = Offset(0, len);

    canvas.drawLine(c - dx, c + dx, paint);
    canvas.drawLine(c - dy, c + dy, paint);

    // petites branches diagonales (optionnel)
    final d = len * 0.55;
    canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), paint);
    canvas.drawLine(c + Offset(-d, d), c + Offset(d, -d), paint);
  }

  @override
  bool shouldRepaint(covariant _TwinklePainter oldDelegate) => true;
}
