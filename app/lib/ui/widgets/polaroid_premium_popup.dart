import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// PolaroidPremiumPopup (10/10)
/// - Photo eject animation (slide out)
/// - Instant photo reveal (fade + scale)
/// - Paper shadows (realistic)
/// - Vintage grain overlay
/// - Gentle tilt
/// - iOS glass close button (blur)
/// ------------------------------------------------------------

Future<void> showPolaroidPremiumPopup({
  required BuildContext context,
  required ImageProvider photo,
  required String title,
  required String description,
  String? usefulInfo,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => _PolaroidPremiumDialog(
      photo: photo,
      title: title,
      description: description,
      usefulInfo: usefulInfo,
    ),
  );
}

class _PolaroidPremiumDialog extends StatefulWidget {
  final ImageProvider photo;
  final String title;
  final String description;
  final String? usefulInfo;

  const _PolaroidPremiumDialog({
    required this.photo,
    required this.title,
    required this.description,
    this.usefulInfo,
  });

  @override
  State<_PolaroidPremiumDialog> createState() => _PolaroidPremiumDialogState();
}

class _PolaroidPremiumDialogState extends State<_PolaroidPremiumDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _lift;
  late final Animation<double> _tilt;
  late final Animation<double> _photoEject; // 0..1

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.00, 0.35, curve: Curves.easeOut)),
    );

    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.00, 0.50, curve: Curves.easeOutBack)),
    );

    _lift = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.00, 0.55, curve: Curves.easeOutCubic)),
    );

    _tilt = Tween<double>(begin: -0.018, end: 0.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.00, 0.70, curve: Curves.easeOut)),
    );

    // Photo eject: starts a little later
    _photoEject = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.18, 0.85, curve: Curves.easeOutCubic)),
    );

    // Start
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, _lift.value),
              child: Transform.scale(
                scale: _scale.value,
                child: Transform.rotate(
                  angle: _tilt.value,
                  child: _PolaroidPremiumCard(
                    photo: widget.photo,
                    title: widget.title,
                    description: widget.description,
                    usefulInfo: widget.usefulInfo,
                    photoEjectT: _photoEject.value,
                    onClose: _close,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PolaroidPremiumCard extends StatelessWidget {
  final ImageProvider photo;
  final String title;
  final String description;
  final String? usefulInfo;
  final double photoEjectT; // 0..1
  final VoidCallback onClose;

  const _PolaroidPremiumCard({
    required this.photo,
    required this.title,
    required this.description,
    required this.photoEjectT,
    required this.onClose,
    this.usefulInfo,
  });

  @override
  Widget build(BuildContext context) {
    // "Paper" tone like your mock
    const paper = Color(0xFFF6F2EA);

    // Responsive size (keeps the Polaroid vibe)
    final w = math.min(MediaQuery.of(context).size.width - 40, 420.0);
    final h = w * 1.18; // vertical Polaroid-ish

    // Eject effect: photo moves slightly upward from inside frame
    final ejectOffset = lerpDouble(18, 0, photoEjectT)!; // starts "deeper", ends "flush"
    final ejectScale = lerpDouble(0.985, 1.0, photoEjectT)!;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Paper + realistic shadow
          Container(
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 30,
                  offset: Offset(0, 18),
                ),
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Photo window (square) with inner shadow feel
                Expanded(
                  flex: 72,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withOpacity(0.06),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 14,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Photo "eject"
                          Transform.translate(
                            offset: Offset(0, ejectOffset),
                            child: Transform.scale(
                              scale: ejectScale,
                              child: _PhotoWithInstantReveal(photo: photo),
                            ),
                          ),

                          // Grain overlay (subtle)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _GrainPainter(intensity: 0.12),
                              ),
                            ),
                          ),

                          // Soft vignette for "instant film" depth
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.10),
                                    ],
                                    radius: 1.0,
                                    center: Alignment.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Text area (bottom)
                Expanded(
                  flex: 46,
                  child: _PolaroidTextArea(
                    title: title,
                    description: description,
                    usefulInfo: usefulInfo,
                  ),
                ),
              ],
            ),
          ),

          // iOS glass close button (top-right)
          Positioned(
            top: -6,
            right: -6,
            child: _GlassCloseButton(onTap: onClose),
          ),
        ],
      ),
    );
  }
}

/// "Instant photo reveal": slight blur -> sharp (simulates developing)
class _PhotoWithInstantReveal extends StatefulWidget {
  final ImageProvider photo;
  const _PhotoWithInstantReveal({required this.photo});

  @override
  State<_PhotoWithInstantReveal> createState() => _PhotoWithInstantRevealState();
}

class _PhotoWithInstantRevealState extends State<_PhotoWithInstantReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final blur = lerpDouble(6.0, 0.0, _t.value)!;
        final fade = lerpDouble(0.75, 1.0, _t.value)!;

        return Opacity(
          opacity: fade,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Image(
              image: widget.photo,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
    );
  }
}

class _PolaroidTextArea extends StatelessWidget {
  final String title;
  final String description;
  final String? usefulInfo;

  const _PolaroidTextArea({
    required this.title,
    required this.description,
    this.usefulInfo,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title (handwritten vibe without external font)
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),

        // "underline" like the mock
        Container(
          height: 1,
          width: double.infinity,
          color: Colors.black.withOpacity(0.20),
        ),
        const SizedBox(height: 10),

        Text(
          description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: t.bodyMedium?.copyWith(height: 1.35),
        ),

        if ((usefulInfo ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.black.withOpacity(0.65)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    usefulInfo!.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// iOS glass close button: blur + translucent + highlight
class _GlassCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GlassCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.70),
                border: Border.all(color: Colors.white.withOpacity(0.65)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.close, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vintage grain overlay (procedural noise)
class _GrainPainter extends CustomPainter {
  final double intensity; // 0..1
  _GrainPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(1337); // fixed seed => stable grain
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw tiny translucent dots
    final dots = (size.width * size.height / 1400).clamp(180, 1200).toInt();
    for (int i = 0; i < dots; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 1.2 + 0.2;

      // Alternate light/dark grains
      final isLight = rnd.nextBool();
      final a = (rnd.nextDouble() * 0.08 + 0.02) * intensity;
      paint.color = isLight
          ? Colors.white.withOpacity(a)
          : Colors.black.withOpacity(a);

      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) =>
      oldDelegate.intensity != intensity;
}
