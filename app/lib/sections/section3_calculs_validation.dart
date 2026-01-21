import 'package:flutter/material.dart';

/// Section 3 - "Calculs & Validation"
/// Style iOS blanc premium + icône carrée + titre + ligne à droite + bullets colorés
class Section3CalculsValidation extends StatelessWidget {
  const Section3CalculsValidation({super.key});

  static const Color _text = Color(0xFF1F2A37); // bleu/noir élégant
  static const Color _line = Color(0xFFE5E7EB); // séparateur
  static const Color _blue = Color(0xFF1A73E8); // bleu principal

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppIconSquare(color: _blue, icon: Icons.calculate_rounded),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre + ligne à droite
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "3. Calculs & Validation",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _text,
                      height: 1.1,
                      letterSpacing: -0.15,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 2),
                      height: 1,
                      color: _line,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              const _BulletLine(dotColor: _blue, text: "Distance & Dénivelé"),
              const _BulletLine(dotColor: _blue, text: "Temps estimé"),
              const _BulletLine(dotColor: _blue, text: "Validation automatique"),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppIconSquare extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _AppIconSquare({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Shine iOS (petit reflet)
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Center(
            child: Icon(icon, size: 30, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  final Color dotColor;

  const _BulletLine({
    required this.text,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2A37),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
