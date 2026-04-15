import 'package:flutter/material.dart';

import '../theme/maslive_theme.dart';

typedef MasliveStandardBottomBarIconBuilder =
    Widget Function(BuildContext context, bool active);

class MasliveStandardBottomBar extends StatelessWidget {
  const MasliveStandardBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.height = defaultHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.backgroundColor = const Color(0xF9FFFFFF),
    this.inactiveColor = const Color(0xFF101828),
    this.includeBottomSafeArea = false,
    this.border,
    this.borderRadius = BorderRadius.zero,
    this.boxShadow = const <BoxShadow>[
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 20,
        offset: Offset(0, -2),
      ),
    ],
  });

  static const double defaultHeight = 68;

  final List<MasliveStandardBottomBarItem> items;
  final int? selectedIndex;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color inactiveColor;
  final bool includeBottomSafeArea;
  final Border? border;
  final BorderRadiusGeometry borderRadius;
  final List<BoxShadow> boxShadow;

  @override
  Widget build(BuildContext context) {
    final bar = Material(
      color: Colors.transparent,
      child: Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          border:
              border ?? const Border(top: BorderSide(color: Color(0x1F0F172A))),
          borderRadius: borderRadius,
          boxShadow: boxShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final action = _MasliveStandardBottomBarAction(
              item: item,
              active: index == selectedIndex,
              inactiveColor: inactiveColor,
            );

            final actionSlot = Expanded(
              child: Center(child: action),
            );

            if (item.tooltip == null || item.tooltip!.trim().isEmpty) {
              return actionSlot;
            }

            return Expanded(
              child: Center(
                child: Tooltip(message: item.tooltip!, child: action),
              ),
            );
          }),
        ),
      ),
    );

    if (!includeBottomSafeArea) {
      return bar;
    }

    return SafeArea(top: false, child: bar);
  }
}

class MasliveStandardBottomBarItem {
  const MasliveStandardBottomBarItem({
    this.icon,
    this.activeIcon,
    this.iconBuilder,
    this.label,
    this.tooltip,
    this.badgeCount = 0,
    required this.onTap,
  }) : assert(
         iconBuilder != null || (icon != null && activeIcon != null),
         'Provide iconBuilder or both icon and activeIcon.',
       );

  final IconData? icon;
  final IconData? activeIcon;
  final MasliveStandardBottomBarIconBuilder? iconBuilder;
  final String? label;
  final String? tooltip;
  final int badgeCount;
  final VoidCallback onTap;
}

class _MasliveStandardBottomBarAction extends StatelessWidget {
  const _MasliveStandardBottomBarAction({
    required this.item,
    required this.active,
    required this.inactiveColor,
  });

  static const LinearGradient _activeGradient = LinearGradient(
    colors: [Color(0xFFFFB26A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const BoxShadow _activeShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 18,
    offset: Offset(0, 8),
  );
  static const double _activePillHeight = 48;
  static const double _activePillWidthWithLabel = 64;
  static const double _activePillWidthIconOnly = 34;
  final MasliveStandardBottomBarItem item;
  final bool active;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final label = item.label?.trim() ?? '';
    final hasLabel = label.isNotEmpty;
    final iconChild =
        item.iconBuilder?.call(context, active) ??
        Icon(
          active ? item.activeIcon : item.icon,
          color: active ? Colors.white : inactiveColor,
          size: hasLabel ? 22 : 24,
        );

    return InkResponse(
      radius: 28,
      onTap: item.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: active ? _activePillHeight : (hasLabel ? 40 : 24),
            constraints: BoxConstraints(
              minWidth: active
                  ? (hasLabel
                        ? _activePillWidthWithLabel
                        : _activePillWidthIconOnly)
                  : 0,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: active ? 12 : 8,
              vertical: active ? 7 : (hasLabel ? 5 : 8),
            ),
            decoration: active
                ? BoxDecoration(
                    gradient: _activeGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MasliveTheme.pink,
                      width: 2,
                    ),
                    boxShadow: const <BoxShadow>[_activeShadow],
                  )
                : null,
            child: SizedBox(
              width: hasLabel ? 44 : 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(child: iconChild),
                  ),
                  if (hasLabel) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active ? Colors.white : inactiveColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (item.badgeCount > 0)
            Positioned(
              right: -10,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: _activeGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
