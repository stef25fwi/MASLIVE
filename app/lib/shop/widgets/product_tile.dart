import 'dart:ui';
import 'package:flutter/material.dart';

/// ===============================
///  MASLIVE – Product Tiles 10/10
/// ===============================
/// - Card premium (rayon + ombre)
/// - Image header + skeleton
/// - Badge stock / rupture
/// - Prix + mini chips (taille/couleur)
/// - Bouton + (ajout panier) en overlay
/// - Responsive + accessible
///
/// Usage:
/// GridView.builder(
///   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
///     crossAxisCount: 2,
///     mainAxisSpacing: 14,
///     crossAxisSpacing: 14,
///     childAspectRatio: 0.76,
///   ),
///   itemCount: products.length,
///   itemBuilder: (_, i) => ProductTile(
///     data: products[i],
///     onTap: () {},
///     onAdd: () {},
///   ),
/// )
///

@immutable
class ProductTileData {
  const ProductTileData({
    required this.title,
    required this.price,
    required this.currency,
    required this.imageUrl,
    this.subtitle,
    this.isAvailable = true,
    this.stockLabel,
    this.badges = const [],
    this.options = const [],
  });

  final String title;
  final double price;
  final String currency; // "€", "XPF", etc.
  final String imageUrl;

  final String? subtitle;
  final bool isAvailable;
  final String? stockLabel; // ex: "En stock", "Rupture"
  final List<String> badges; // ex: ["Officiel", "Nouveau"]
  final List<String> options; // ex: ["S-XL", "Noir/Blanc"]
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.data,
    this.onTap,
    this.onAdd,
    this.heroTag,
  });

  final ProductTileData data;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(22);

    final priceText = _formatPrice(data.price, data.currency);

    return Semantics(
      button: true,
      label: 'Article ${data.title}, prix $priceText',
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: data.isAvailable ? 1 : 0.62,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: Colors.white.withValues(alpha: 0.92),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ],
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  // Subtle glass gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.75),
                            Colors.white.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // IMAGE HEADER
                      Expanded(
                        child: _ImageHeader(
                          url: data.imageUrl,
                          heroTag: heroTag,
                          radius: 22,
                        ),
                      ),

                      // TEXT AREA
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              data.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),

                            if ((data.subtitle ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                data.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],

                            const SizedBox(height: 10),

                            // Price + stock
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    priceText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                _StockPill(
                                  label:
                                      data.stockLabel ??
                                      (data.isAvailable
                                          ? 'En stock'
                                          : 'Rupture'),
                                  available: data.isAvailable,
                                ),
                              ],
                            ),

                            if (data.options.isNotEmpty ||
                                data.badges.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...data.badges
                                      .take(2)
                                      .map(
                                        (b) => _MiniChip(text: b, filled: true),
                                      ),
                                  ...data.options
                                      .take(2)
                                      .map(
                                        (o) =>
                                            _MiniChip(text: o, filled: false),
                                      ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ADD BUTTON
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _AddButton(
                      enabled: data.isAvailable,
                      onPressed: data.isAvailable ? onAdd : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageHeader extends StatelessWidget {
  const _ImageHeader({required this.url, this.heroTag, required this.radius});

  final String url;
  final Object? heroTag;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);

    final image = ClipRRect(
      borderRadius: BorderRadius.only(topLeft: r.topLeft, topRight: r.topRight),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _NetworkImageWithSkeleton(url: url),

          // soft top shine
          Positioned(
            left: -40,
            top: -60,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 220,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // bottom fade for text separation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (heroTag == null) return image;

    return Hero(tag: heroTag!, child: image);
  }
}

class _NetworkImageWithSkeleton extends StatefulWidget {
  const _NetworkImageWithSkeleton({required this.url});
  final String url;

  @override
  State<_NetworkImageWithSkeleton> createState() =>
      _NetworkImageWithSkeletonState();
}

class _NetworkImageWithSkeletonState extends State<_NetworkImageWithSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) {
      return Container(
        alignment: Alignment.center,
        color: Colors.black.withValues(alpha: 0.04),
        child: Opacity(
          opacity: 0.70,
          child: Image.asset(
            'assets/splash/maslivesmall.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.image_not_supported_rounded,
              size: 28,
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }

    // Support: utiliser une image locale (assets/*) même si le champ s'appelle "imageUrl".
    if (widget.url.startsWith('assets/')) {
      return Image.asset(
        widget.url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            alignment: Alignment.center,
            color: Colors.black.withValues(alpha: 0.04),
            child: Icon(
              Icons.image_not_supported_rounded,
              size: 28,
              color: Colors.black.withValues(alpha: 0.35),
            ),
          );
        },
      );
    }

    return Image.network(
      widget.url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return CustomPaint(
              painter: _SkeletonPainter(t: t),
              child: const SizedBox.expand(),
            );
          },
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          alignment: Alignment.center,
          color: Colors.black.withValues(alpha: 0.04),
          child: Icon(
            Icons.image_not_supported_rounded,
            size: 28,
            color: Colors.black.withValues(alpha: 0.35),
          ),
        );
      },
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = Colors.black.withValues(alpha: 0.05);
    canvas.drawRect(Offset.zero & size, base);

    final shimmer = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + 2 * t, -1),
        end: Alignment(0 + 2 * t, 1),
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.20),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, shimmer);

    // placeholder icon
    final iconPaint = Paint()..color = Colors.black.withValues(alpha: 0.10);
    final center = Offset(size.width * 0.5, size.height * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 44, height: 34),
        const Radius.circular(10),
      ),
      iconPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: enabled ? 0.60 : 0.40),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                Icons.add_rounded,
                size: 22,
                color: Colors.black.withValues(alpha: enabled ? 0.85 : 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.label, required this.available});
  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final bg = available
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final fg = available
        ? Colors.black.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.text, required this.filled});
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled
            ? Colors.black.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Colors.black.withValues(alpha: 0.70),
          height: 1,
        ),
      ),
    );
  }
}

String _formatPrice(double price, String currency) {
  // Format simple FR: 12,50 €
  final s = price.toStringAsFixed(2).replaceAll('.', ',');
  return '$s $currency';
}
