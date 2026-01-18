import 'package:flutter/material.dart';

class RainbowHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double height;

  const RainbowHeader({
    super.key,
    required this.title,
    this.trailing,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  title,
                  style: const TextStyle(
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
          ],
        ),
      ),
    );
  }
}
