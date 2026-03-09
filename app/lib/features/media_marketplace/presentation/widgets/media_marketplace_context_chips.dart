import 'package:flutter/material.dart';

class MediaMarketplaceContextChips extends StatelessWidget {
  const MediaMarketplaceContextChips({
    super.key,
    required this.eventId,
    this.circuitName,
  });

  final String eventId;
  final String? circuitName;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _ContextChip(
          icon: Icons.event_outlined,
          label: 'Événement',
          value: eventId,
          foregroundColor: const Color(0xFF155EEF),
          backgroundColor: const Color(0xFFEFF4FF),
        ),
        if (circuitName?.trim().isNotEmpty == true)
          _ContextChip(
            icon: Icons.route_outlined,
            label: 'Circuit',
            value: circuitName!.trim(),
            foregroundColor: const Color(0xFF027A48),
            backgroundColor: const Color(0xFFECFDF3),
          ),
      ],
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}