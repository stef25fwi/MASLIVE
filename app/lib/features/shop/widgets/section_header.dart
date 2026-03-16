import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onTapAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onTapAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
              color: const Color(0xFF101010),
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onTapAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: const Color(0xFF6A6A6A),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
