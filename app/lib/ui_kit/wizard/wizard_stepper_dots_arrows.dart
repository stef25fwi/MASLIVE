import 'package:flutter/material.dart';

import '../tokens/maslive_tokens.dart';

class WizardStepperDotsArrows extends StatefulWidget {
  final int currentStep;
  final List<String> labels;
  final ValueChanged<int>? onStepTap;
  final EdgeInsetsGeometry padding;

  /// Permet de conserver la logique existante de verrouillage des étapes.
  final bool Function(int step)? isStepEnabled;

  /// Permet de conserver la logique existante de complétion.
  final bool Function(int step)? isStepCompleted;

  const WizardStepperDotsArrows({
    super.key,
    required this.currentStep,
    required this.labels,
    this.onStepTap,
    this.isStepEnabled,
    this.isStepCompleted,
    this.padding = const EdgeInsets.symmetric(horizontal: MasliveTokens.m),
  });

  @override
  State<WizardStepperDotsArrows> createState() => _WizardStepperDotsArrowsState();
}

class _WizardStepperDotsArrowsState extends State<WizardStepperDotsArrows> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _keys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerActive());
  }

  @override
  void didUpdateWidget(covariant WizardStepperDotsArrows oldWidget) {
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
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 260),
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
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / 390.0).clamp(0.85, 1.15);
    final height = 52.0 * scale;
    final circleSize = 30.0 * scale;
    final fontSize = 13.0 * scale;
    final arrowSize = 18.0 * scale;

    return SizedBox(
      height: height,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        itemCount: widget.labels.length,
        separatorBuilder: (context, index) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: MasliveTokens.xs),
              Icon(
                Icons.chevron_right,
                size: arrowSize,
                color: MasliveTokens.textSoft.withValues(alpha: 0.65),
              ),
              const SizedBox(width: MasliveTokens.xs),
            ],
          );
        },
        itemBuilder: (context, index) {
          final isEnabled = widget.isStepEnabled?.call(index) ?? true;
          final isDone = widget.isStepCompleted?.call(index) ?? (index < widget.currentStep);
          final isActive = index == widget.currentStep;

          final Color bg;
          final Color fg;
          final BorderSide border;

          if (isActive) {
            bg = MasliveTokens.primary.withValues(alpha: 0.15);
            fg = MasliveTokens.primary;
            border = BorderSide(color: MasliveTokens.primary.withValues(alpha: 0.25));
          } else if (isDone) {
            bg = Colors.white.withValues(alpha: 0.80);
            fg = MasliveTokens.text;
            border = BorderSide(color: MasliveTokens.borderSoft);
          } else {
            bg = Colors.white.withValues(alpha: 0.72);
            fg = MasliveTokens.textSoft;
            border = BorderSide(color: MasliveTokens.borderSoft);
          }

          final circle = AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: circleSize,
            height: circleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(border),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w800,
                color: fg.withValues(alpha: isEnabled ? 1.0 : 0.40),
              ),
            ),
          );

          return Opacity(
            opacity: isEnabled ? 1.0 : 0.6,
            child: Tooltip(
              message: widget.labels[index],
              child: InkWell(
                key: _keys[index],
                onTap: (!isEnabled || widget.onStepTap == null)
                    ? null
                    : () => widget.onStepTap!(index),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
