import 'package:flutter/material.dart';

class BloomArtOfferStatusBadge extends StatelessWidget {
  const BloomArtOfferStatusBadge({
    super.key,
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  _BadgeStyle _resolveStyle(String rawStatus) {
    switch (rawStatus) {
      case 'auto_accepted':
        return const _BadgeStyle('Auto-acceptee', Color(0xFFE8F8ED), Color(0xFF1B7F46));
      case 'accepted':
        return const _BadgeStyle('Acceptee', Color(0xFFE7F1FF), Color(0xFF1A5FB4));
      case 'declined':
        return const _BadgeStyle('Refusee', Color(0xFFFFECEB), Color(0xFFC0392B));
      case 'checkout_started':
        return const _BadgeStyle('Checkout lance', Color(0xFFFFF5E3), Color(0xFFB57414));
      case 'paid':
        return const _BadgeStyle('Payee', Color(0xFFEAF7F3), Color(0xFF0D7A5F));
      case 'pending':
      default:
        return const _BadgeStyle('En attente', Color(0xFFF1EDE7), Color(0xFF6A5A4C));
    }
  }
}

class _BadgeStyle {
  const _BadgeStyle(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}