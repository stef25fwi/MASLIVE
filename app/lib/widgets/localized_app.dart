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
    // Popup langue désactivé - retour direct du child
    return child;
    
    // Code commenté - popup langue en haut
    // if (!showLanguageSidebar) {
    //   return child;
    // }
    //
    // return Stack(
    //   children: [
    //     child,
    //     Positioned(
    //       top: 50,
    //       right: 16,
    //       child: _LanguageSwitcher(),
    //     ),
    //   ],
    // );
  }
}

// Classe _LanguageSwitcher supprimée - popup langue désactivé
