import 'package:flutter/material.dart';

class ChangeNotifierProviderLite extends InheritedNotifier<ChangeNotifier> {
  const ChangeNotifierProviderLite({
    super.key,
    required ChangeNotifier super.notifier,
    required super.child,
  });

  static T of<T extends ChangeNotifier>(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<ChangeNotifierProviderLite>();
    if (widget == null) {
      throw Exception('ChangeNotifierProviderLite not found');
    }
    final notifier = widget.notifier;
    if (notifier == null) {
      throw Exception('ChangeNotifierProviderLite notifier is null');
    }
    return notifier as T;
  }
}