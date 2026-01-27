import 'package:flutter/material.dart';

class RainbowHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final TextStyle? titleStyle;

  const RainbowHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.height = 150,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.topRight,
                  colors: [
                    Color(0xFFFFE36A),
                    Color(0xFFFF7BC5),
                    Color(0xFF7CE0FF),
                  ],
                ),
              ),
            ),
          ),
          // Honeycomb texture overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/textures/maslive_honeycomb_2048.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      title,
                      style: titleStyle ?? const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                if (trailing != null)
                  Positioned(
                    right: 16,
                    top: 14,
                    child: trailing!,
                  ),
                if (leading != null)
                  Positioned(
                    left: 16,
                    top: 14,
                    child: leading!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
