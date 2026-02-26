import 'package:flutter/material.dart';

// Centralise l'affichage des SnackBars en haut (floating + marge).
class TopSnackBar {
  static void show(BuildContext context, SnackBar snackBar) {
    final messenger = ScaffoldMessenger.of(context);

    final media = MediaQuery.of(context);
    final top = media.padding.top + kToolbarHeight + 8;

    // Hack de positionnement: SnackBar est ancré en bas.
    // En mode floating, une grande marge basse le "pousse" vers le haut.
    // On garde une zone de confort pour éviter de couvrir l'AppBar.
    final viewportH = media.size.height;
    final bottom = (viewportH - top - 72).clamp(0.0, viewportH);

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: snackBar.content,
          action: snackBar.action,
          actionOverflowThreshold: snackBar.actionOverflowThreshold,
          animation: snackBar.animation,
          backgroundColor: snackBar.backgroundColor,
          closeIconColor: snackBar.closeIconColor,
          dismissDirection: DismissDirection.up,
          duration: snackBar.duration,
          elevation: snackBar.elevation,
          margin: EdgeInsets.fromLTRB(16, top, 16, bottom),
          onVisible: snackBar.onVisible,
          padding: snackBar.padding,
          shape: snackBar.shape,
          showCloseIcon: snackBar.showCloseIcon,
          width: snackBar.width,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static void showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isError ? scheme.error : scheme.inverseSurface;
    final fg = isError ? scheme.onError : scheme.onInverseSurface;

    show(
      context,
      SnackBar(
        content: Text(message, style: TextStyle(color: fg)),
        backgroundColor: bg,
        duration: duration,
      ),
    );
  }
}
