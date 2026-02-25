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
  final EdgeInsets margin;
  final double horizontalPadding;
  final double verticalPadding;
  final List<HomeVerticalNavItem> items;

  const HomeVerticalNavMenu({
    super.key,
    required this.items,
    this.margin = const EdgeInsets.only(right: 0),
    this.horizontalPadding = 6,
    this.verticalPadding = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.40),
        boxShadow: MasliveTheme.cardShadow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
          bottom: Radius.circular(24),
        ),
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
  }
}

class HomeVerticalNavActionItem extends StatelessWidget {
  final HomeVerticalNavItem item;

  const HomeVerticalNavActionItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final showSelectedBackground =
        item.highlightBackgroundOnSelected && item.selected;

    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        width: 60,
        height: 60,
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
                          size: 28,
                          color: item.selected && item.tintOnSelected
                              ? Colors.white
                              : MasliveTheme.textPrimary,
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
                      width: item.label.isEmpty ? 32 : 28,
                      height: item.label.isEmpty ? 32 : 28,
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
                      size: item.label.isEmpty ? 32 : 28,
                      color: item.selected && item.tintOnSelected
                          ? Colors.white
                          : MasliveTheme.textPrimary,
                    ),
                  if (item.label.isNotEmpty) const SizedBox(height: 4),
                  if (item.label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: item.selected && item.tintOnSelected
                              ? Colors.white
                              : MasliveTheme.textSecondary,
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
