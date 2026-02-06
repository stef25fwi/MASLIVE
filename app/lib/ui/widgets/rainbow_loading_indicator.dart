import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Indicateur de chargement avec animation arc-en-ciel (rainbow)
class RainbowLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? backgroundColor;
  final bool showLabel;
  final String label;

  const RainbowLoadingIndicator({
    super.key,
    this.size = 80.0,
    this.backgroundColor,
    this.showLabel = true,
    this.label = 'Chargement...',
  });

  @override
  State<RainbowLoadingIndicator> createState() =>
      _RainbowLoadingIndicatorState();
}

class _RainbowLoadingIndicatorState extends State<RainbowLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RainbowPainter(
                rotation: _animation.value,
              ),
            );
          },
        ),
        if (widget.showLabel) ...[
          const SizedBox(height: 16),
          Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ],
    );
  }
}

/// Peintre personnalisé pour le loading arc-en-ciel
class _RainbowPainter extends CustomPainter {
  final double rotation;

  _RainbowPainter({required this.rotation});

  static const List<Color> rainbowColors = [
    Color(0xFFFF0000), // Rouge
    Color(0xFFFF7F00), // Orange
    Color(0xFFFFFF00), // Jaune
    Color(0xFF00FF00), // Vert
    Color(0xFF0000FF), // Bleu
    Color(0xFF4B0082), // Indigo
    Color(0xFF9400D3), // Violet
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 8.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Dessiner plusieurs arcs pour créer l'effet arc-en-ciel
    for (int i = 0; i < rainbowColors.length; i++) {
      final paint = Paint()
        ..color = rainbowColors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final arcRadius = radius - (i * strokeWidth * 0.8);
      if (arcRadius > 0) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset.zero,
            width: arcRadius * 2,
            height: arcRadius * 2,
          ),
          0,
          math.pi * 1.5,
          false,
          paint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RainbowPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

/// Version simplifiée avec progress (0.0 à 1.0)
class RainbowProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 à 1.0
  final double size;
  final String? label;

  const RainbowProgressIndicator({
    super.key,
    required this.progress,
    this.size = 80.0,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _RainbowProgressPainter(
            progress: progress.clamp(0.0, 1.0),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey[500],
              ),
        ),
      ],
    );
  }
}

class _RainbowProgressPainter extends CustomPainter {
  final double progress;

  _RainbowProgressPainter({required this.progress});

  static const List<Color> rainbowColors = [
    Color(0xFFFF0000), // Rouge
    Color(0xFFFF7F00), // Orange
    Color(0xFFFFFF00), // Jaune
    Color(0xFF00FF00), // Vert
    Color(0xFF0000FF), // Bleu
    Color(0xFF4B0082), // Indigo
    Color(0xFF9400D3), // Violet
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cercle gris de fond
    final backgroundPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 4, backgroundPaint);

    // Cercles arc-en-ciel de progression
    final totalSweep = math.pi * 2 * progress;
    var currentSweep = 0.0;

    for (int i = 0; i < rainbowColors.length; i++) {
      if (currentSweep >= totalSweep) break;

      final segmentSweep = (totalSweep - currentSweep).clamp(
        0.0,
        (math.pi * 2) / rainbowColors.length,
      );

      final paint = Paint()
        ..color = rainbowColors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCenter(
          center: center,
          width: (radius - 4) * 2,
          height: (radius - 4) * 2,
        ),
        -math.pi / 2 + currentSweep,
        segmentSweep,
        false,
        paint,
      );

      currentSweep += segmentSweep;
    }
  }

  @override
  bool shouldRepaint(_RainbowProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
