import 'dart:ui';

import 'package:flutter/material.dart';

import '../ui/theme/maslive_theme.dart';

class HomeVerticalNavItem {
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onTap;
  final bool fullBleed;
  final bool tintOnSelected;
  final bool highlightBackgroundOnSelected;
  final bool showBorder;

  const HomeVerticalNavItem({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.selected,
    required this.onTap,
    this.fullBleed = false,
    this.tintOnSelected = true,
    this.highlightBackgroundOnSelected = true,
    this.showBorder = true,
  }) : assert(icon != null || iconWidget != null);
}

class HomeVerticalNavMenu extends StatelessWidget {
  static const double boutiqueBackgroundAlpha = 0.82;
  static const double boutiqueBlurSigma = 14;
  static const Color boutiqueBorderColor = Color(0x1F0F172A);
  static const List<BoxShadow> boutiqueShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 24,
      offset: Offset(0, 14),
    ),
  ];

  final EdgeInsets margin;
  final double horizontalPadding;
  final double verticalPadding;
  final double backgroundAlpha;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;
  final BorderRadius borderRadius;
  final List<BoxShadow>? boxShadow;
  final List<HomeVerticalNavItem> items;

  const HomeVerticalNavMenu({
    super.key,
    required this.items,
    this.margin = const EdgeInsets.only(right: 0),
    this.horizontalPadding = 6,
    this.verticalPadding = 10,
    this.backgroundAlpha = 0.40,
    this.borderColor,
    this.borderWidth = 1,
    this.blurSigma = 0,
    this.borderRadius = const BorderRadius.vertical(
      top: Radius.circular(24),
      bottom: Radius.circular(24),
    ),
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              HomeVerticalNavActionItem(item: items[i]),
              if (i != items.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: boxShadow ?? MasliveTheme.floatingShadow,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: backgroundAlpha),
                borderRadius: borderRadius,
                border: borderColor == null
                    ? null
                    : Border.all(color: borderColor!, width: borderWidth),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class HomeVerticalNavActionItem extends StatelessWidget {
  final HomeVerticalNavItem item;
  static const Color _inactiveColor = Color(0xFF101828);

  static const double _buttonSize = 56;
  static const double _iconSize = 26;
  static const double _iconSizeNoLabel = 30;

  const HomeVerticalNavActionItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final showSelectedBackground =
        item.highlightBackgroundOnSelected && item.selected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: Container(
        width: _buttonSize,
        height: _buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: showSelectedBackground ? MasliveTheme.actionGradient : null,
          color: showSelectedBackground
              ? null
              : Colors.white.withValues(alpha: 0.92),
          border: item.showBorder
              ? Border.all(
                  color: item.selected
                      ? MasliveTheme.pink
                      : MasliveTheme.divider,
                  width: item.selected ? 2.0 : 1.0,
                )
              : null,
          boxShadow: item.selected ? MasliveTheme.cardShadow : const [],
        ),
        child: item.fullBleed
            ? ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.iconWidget != null)
                      item.selected && item.tintOnSelected
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                              child: item.iconWidget!,
                            )
                          : item.iconWidget!,
                    if (item.icon != null)
                      Center(
                        child: Icon(
                          item.icon,
                          size: _iconSize,
                          color: item.selected && item.tintOnSelected
                              ? Colors.white
                              : _inactiveColor,
                        ),
                      ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.iconWidget != null)
                    SizedBox(
                      width: item.label.isEmpty ? _iconSizeNoLabel : _iconSize,
                      height: item.label.isEmpty ? _iconSizeNoLabel : _iconSize,
                      child: item.selected && item.tintOnSelected
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                              child: item.iconWidget!,
                            )
                          : item.iconWidget!,
                    )
                  else
                    Icon(
                      item.icon,
                      size: item.label.isEmpty ? _iconSizeNoLabel : _iconSize,
                      color: item.selected && item.tintOnSelected
                          ? Colors.white
                          : _inactiveColor,
                    ),
                  if (item.label.isNotEmpty) const SizedBox(height: 4),
                  if (item.label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: item.selected && item.tintOnSelected
                              ? Colors.white
                              : _inactiveColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 8,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
