import 'dart:ui';

import 'package:flutter/material.dart';

class MasliveOption1BottomBar extends StatelessWidget {
  const MasliveOption1BottomBar({
    super.key,
    required this.items,
    this.selectedIndex,
    this.onTap,
    this.height = 94,
    this.horizontalPadding = 16,
  });

  final List<MasliveBottomBarEntry> items;
  final int? selectedIndex;
  final ValueChanged<int>? onTap;
  final double height;
  final double horizontalPadding;

  void _handleTap(int index) {
    final entryTap = items[index].onTap;
    if (entryTap != null) {
      entryTap();
      return;
    }
    onTap?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(32);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0.28),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == selectedIndex;
              final action = GestureDetector(
                onTap: () => _handleTap(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFB36A),
                              Color(0xFFFF7CC8),
                              Color(0xFF6AA9FF),
                            ],
                          )
                        : null,
                    color: selected ? null : Colors.transparent,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFFF9F8C,
                              ).withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child:
                              item.iconWidget ??
                              Icon(
                                item.icon,
                                size: 24,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF1E2430),
                              ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.05,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF1F2633),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final wrappedAction =
                  item.tooltip == null || item.tooltip!.trim().isEmpty
                  ? action
                  : Tooltip(message: item.tooltip!, child: action);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: wrappedAction,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class MasliveOption1VerticalNav extends StatelessWidget {
  const MasliveOption1VerticalNav({
    super.key,
    required this.items,
    this.onTap,
    this.width = 86,
    this.buttonHeight = 78,
    this.spacing = 10,
  });

  final List<MasliveVerticalNavItem> items;
  final ValueChanged<int>? onTap;
  final double width;
  final double buttonHeight;
  final double spacing;

  void _handleTap(int index) {
    final itemTap = items[index].onTap;
    if (itemTap != null) {
      itemTap();
      return;
    }
    onTap?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : spacing,
            ),
            child: MasliveGlassButton(
              width: width,
              height: buttonHeight,
              icon: item.icon,
              iconWidget: item.iconWidget,
              label: item.label,
              selected: item.selected,
              fullBleed: item.fullBleed,
              tintOnSelected: item.tintOnSelected,
              showBorder: item.showBorder,
              onTap: () => _handleTap(index),
            ),
          );
        }),
      ),
    );
  }
}

class MasliveGlassButton extends StatelessWidget {
  const MasliveGlassButton({
    super.key,
    required this.width,
    required this.height,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.fullBleed = false,
    this.tintOnSelected = true,
    this.showBorder = true,
  }) : assert(icon != null || iconWidget != null);

  final double width;
  final double height;
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final bool selected;
  final bool fullBleed;
  final bool tintOnSelected;
  final bool showBorder;
  final VoidCallback onTap;

  Widget _buildVisual() {
    if (fullBleed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox.expand(
          child:
              iconWidget ??
              Center(
                child: Icon(
                  icon,
                  size: 28,
                  color: selected && tintOnSelected
                      ? Colors.white
                      : const Color(0xFF1F2633),
                ),
              ),
        ),
      );
    }

    final Widget visual = iconWidget != null
        ? SizedBox(width: 28, height: 28, child: Center(child: iconWidget!))
        : Icon(
            icon,
            size: 26,
            color: selected && tintOnSelected
                ? Colors.white
                : const Color(0xFF1F2633),
          );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        visual,
        if (label.isNotEmpty) const SizedBox(height: 6),
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected && tintOnSelected
                    ? Colors.white
                    : const Color(0xFF2B3240),
                letterSpacing: -0.2,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(26);
    final boxShadow = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: selected ? 0.20 : 0.14),
        blurRadius: selected ? 34 : 26,
        offset: const Offset(0, 16),
        spreadRadius: selected ? 1.5 : 0.5,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: selected ? 0.08 : 0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
      if (selected)
        BoxShadow(
          color: const Color(0xFFFFAA90).withValues(alpha: 0.28),
          blurRadius: 22,
          offset: const Offset(0, 8),
          spreadRadius: 1,
        ),
    ];

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: boxShadow,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFC07A),
                          Color(0xFFFF9ECF),
                          Color(0xFF84B7FF),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.84),
                          Colors.white.withValues(alpha: 0.60),
                        ],
                      ),
                border: showBorder
                    ? Border.all(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.40)
                            : Colors.white.withValues(alpha: 0.70),
                        width: 1.1,
                      )
                    : null,
              ),
              child: _buildVisual(),
            ),
          ),
        ),
      ),
    );
  }
}

class MasliveBottomBarEntry {
  const MasliveBottomBarEntry({
    required this.label,
    this.icon,
    this.iconWidget,
    this.tooltip,
    this.onTap,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final String? tooltip;
  final VoidCallback? onTap;
}

class MasliveVerticalNavItem {
  const MasliveVerticalNavItem({
    required this.label,
    required this.selected,
    this.icon,
    this.iconWidget,
    this.onTap,
    this.fullBleed = false,
    this.tintOnSelected = true,
    this.showBorder = true,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool fullBleed;
  final bool tintOnSelected;
  final bool showBorder;
}
