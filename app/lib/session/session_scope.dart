import 'package:flutter/widgets.dart';
import 'session_controller.dart';

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static SessionController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope introuvable dans l’arbre.');
    return scope!.notifier!;
  }
}
