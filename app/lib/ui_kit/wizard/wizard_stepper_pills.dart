import 'package:flutter/material.dart';

import '../tokens/maslive_tokens.dart';

class WizardStepperPills extends StatefulWidget {
  final int currentStep;
  final List<String> labels;
  final ValueChanged<int>? onStepTap;
  final EdgeInsetsGeometry padding;

  /// Permet de conserver la logique existante de verrouillage des étapes.
  final bool Function(int step)? isStepEnabled;

  /// Permet de conserver la logique existante de complétion.
  final bool Function(int step)? isStepCompleted;

  const WizardStepperPills({
    super.key,
    required this.currentStep,
    required this.labels,
    this.onStepTap,
    this.isStepEnabled,
    this.isStepCompleted,
    this.padding = const EdgeInsets.symmetric(horizontal: MasliveTokens.m),
  });

  @override
  State<WizardStepperPills> createState() => _WizardStepperPillsState();
}

class _WizardStepperPillsState extends State<WizardStepperPills> {
  @override
  Widget build(BuildContext context) {
    Widget buildStep(int index) {
      final label = widget.labels[index];
      final isEnabled = widget.isStepEnabled?.call(index) ?? true;
      final isDone = widget.isStepCompleted?.call(index) ?? (index < widget.currentStep);
      final isActive = index == widget.currentStep;

      final circleColor = isDone
          ? MasliveTokens.success
          : isActive
          ? MasliveTokens.primary
          : isEnabled
          ? Colors.grey.shade300
          : Colors.grey.shade200;

      final circleTextColor = (isActive || isDone)
          ? Colors.white
          : isEnabled
          ? Colors.black
          : Colors.black38;

      final labelColor = isEnabled || isActive ? MasliveTokens.text : Colors.black38;

      return Expanded(
        child: InkWell(
          onTap: (!isEnabled || widget.onStepTap == null) ? null : () => widget.onStepTap!(index),
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: circleTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final total = widget.labels.length;
    final topCount = total <= 4 ? total : 4;
    final bottomCount = total - topCount;

    return Padding(
      padding: widget.padding,
      child: SizedBox(
        height: 112,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < topCount; i++) buildStep(i),
                ],
              ),
            ),
            if (bottomCount > 0)
              Expanded(
                child: Row(
                  children: [
                    for (var i = topCount; i < total; i++) buildStep(i),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
