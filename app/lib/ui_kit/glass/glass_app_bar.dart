import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/maslive_tokens.dart';
import 'glass_panel.dart';

/// Apple-like glass app bar.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const GlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: GlassPanel(
        radius: 0,
        blur: MasliveTokens.blurM,
        opacity: 0.76,
        padding: const EdgeInsets.symmetric(horizontal: MasliveTokens.m),
        child: SizedBox(
          height: 56,
          child: IconTheme(
            data: IconThemeData(
              color: MasliveTokens.text,
              size: 22,
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MasliveTokens.text,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: leading ??
                          IconButton(
                            icon: const Icon(CupertinoIcons.back),
                            onPressed: () => Navigator.maybePop(context),
                            tooltip: 'Retour',
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: (actions == null || actions!.isEmpty)
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions!,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
