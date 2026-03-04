import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/maslive_tokens.dart';

class WizardStepperPills extends StatefulWidget {
  final int currentStep;
  final List<String> labels;
  final ValueChanged<int>? onStepTap;

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
  });

  @override
  State<WizardStepperPills> createState() => _WizardStepperPillsState();
}

class _WizardStepperPillsState extends State<WizardStepperPills> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _keys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerActive());
  }

  @override
  void didUpdateWidget(covariant WizardStepperPills oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKeys();
    if (oldWidget.currentStep != widget.currentStep) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerActive());
    }
  }

  void _syncKeys() {
    if (_keys.length == widget.labels.length) return;
    _keys
      ..clear()
      ..addAll(List<GlobalKey>.generate(widget.labels.length, (_) => GlobalKey()));
  }

  void _centerActive() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    final i = widget.currentStep.clamp(0, widget.labels.length - 1);
    final ctx = _keys[i].currentContext;
    if (ctx == null) return;

    // Scrollable.ensureVisible centre l'item "au mieux".
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MasliveTokens.m),
        itemBuilder: (context, index) {
          final label = widget.labels[index];
          final isEnabled = widget.isStepEnabled?.call(index) ?? true;
          final isDone = widget.isStepCompleted?.call(index) ?? (index < widget.currentStep);
          final isActive = index == widget.currentStep;

          final Color fg;
          final Color bg;
          final BorderSide border;

          if (isDone) {
            fg = MasliveTokens.text;
            bg = Colors.white.withValues(alpha: 0.76);
            border = BorderSide(color: MasliveTokens.borderSoft);
          } else if (isActive) {
            fg = MasliveTokens.primary;
            bg = MasliveTokens.primary.withValues(alpha: 0.15);
            border = BorderSide(color: MasliveTokens.primary.withValues(alpha: 0.22));
          } else {
            fg = MasliveTokens.textSoft;
            bg = Colors.white.withValues(alpha: 0.74);
            border = BorderSide(color: MasliveTokens.borderSoft);
          }

          Widget pillChild = AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: MasliveTokens.m,
              vertical: MasliveTokens.s,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(MasliveTokens.rPill),
              border: Border.fromBorderSide(border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDone) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: MasliveTokens.success,
                      borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: MasliveTokens.xs),
                ] else if (isActive) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MasliveTokens.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: MasliveTokens.xs),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                    color: fg.withValues(alpha: isEnabled ? 1.0 : 0.40),
                  ),
                ),
              ],
            ),
          );

          // Glass blur behind (light, cheap).
          pillChild = ClipRRect(
            borderRadius: BorderRadius.circular(MasliveTokens.rPill),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: MasliveTokens.blurM,
                sigmaY: MasliveTokens.blurM,
              ),
              child: pillChild,
            ),
          );

          if (isActive) {
            pillChild = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                pillChild,
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: 3,
                  width: 22,
                  decoration: BoxDecoration(
                    color: MasliveTokens.primary.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            );
          }

          return Opacity(
            opacity: isEnabled ? 1.0 : 0.6,
            child: InkWell(
              key: _keys[index],
              onTap: (!isEnabled || widget.onStepTap == null)
                  ? null
                  : () => widget.onStepTap!(index),
              borderRadius: BorderRadius.circular(MasliveTokens.rPill),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: pillChild,
              ),
            ),
          );
        },
        separatorBuilder: (context, _) => const SizedBox(width: MasliveTokens.s),
        itemCount: widget.labels.length,
      ),
    );
  }
}
