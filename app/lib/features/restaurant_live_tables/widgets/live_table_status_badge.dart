import 'package:flutter/material.dart';

import '../models/live_table_state.dart';

class LiveTableStatusBadge extends StatelessWidget {
  const LiveTableStatusBadge({
    super.key,
    required this.status,
    required this.isFresh,
  });

  final LiveTableStatus status;
  final bool isFresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String label;
    Color bg;
    Color fg;

    switch (status) {
      case LiveTableStatus.available:
        label = 'Tables disponibles';
        bg = const Color(0xFFE7F8EE);
        fg = const Color(0xFF0E7A34);
        break;
      case LiveTableStatus.limited:
        label = 'Affluence moderee';
        bg = const Color(0xFFFFF4E5);
        fg = const Color(0xFF9A5A00);
        break;
      case LiveTableStatus.full:
        label = 'Complet';
        bg = const Color(0xFFFFE8E8);
        fg = const Color(0xFF9D1C1C);
        break;
      case LiveTableStatus.closed:
        label = 'Ferme';
        bg = const Color(0xFFEDF1F7);
        fg = const Color(0xFF344255);
        break;
      case LiveTableStatus.unknown:
        label = 'Statut indisponible';
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
        break;
    }

    if (!isFresh) {
      label = '$label · maj ancienne';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
