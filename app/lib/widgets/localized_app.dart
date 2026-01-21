import 'package:flutter/material.dart';

class LocalizedApp extends StatelessWidget {
  final Widget child;
  final bool showLanguageSidebar;

  const LocalizedApp({
    super.key,
    required this.child,
    this.showLanguageSidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
