import 'package:flutter/material.dart';
import '../widgets/language_sidebar.dart';

class LocalizedApp extends StatelessWidget {
  final Widget child;
  final bool showLanguageSidebar;

  const LocalizedApp({
    super.key,
    required this.child,
    this.showLanguageSidebar = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showLanguageSidebar) {
      return child;
    }

    return Row(
      children: [
        Expanded(child: child),
        LanguageSidebar(),
      ],
    );
  }
}
