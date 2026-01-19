import 'package:flutter/material.dart';
import '../widgets/language_sidebar.dart';

class LocalizedApp extends StatefulWidget {
  final Widget child;
  final bool showLanguageSidebar;

  const LocalizedApp({
    super.key,
    required this.child,
    this.showLanguageSidebar = true,
  });

  @override
  State<LocalizedApp> createState() => _LocalizedAppState();
}

class _LocalizedAppState extends State<LocalizedApp> {
  bool _sidebarVisible = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.showLanguageSidebar) {
      return widget.child;
    }

    return Stack(
      children: [
        Row(
          children: [
            Expanded(child: widget.child),
            if (_sidebarVisible) LanguageSidebar(),
          ],
        ),
        
        // Onglet indicateur (visible uniquement quand sidebar masquée)
        if (!_sidebarVisible)
          Positioned(
            right: 0,
            top: 100,
            child: GestureDetector(
              onTap: () => setState(() => _sidebarVisible = true),
              child: Container(
                width: 12,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Overlay pour fermer la sidebar (quand visible)
        if (_sidebarVisible)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _sidebarVisible = false),
              child: Container(color: Colors.transparent),
            ),
          ),
      ],
    );
  }
}
