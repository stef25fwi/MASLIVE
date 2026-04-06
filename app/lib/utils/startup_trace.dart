import 'package:flutter/foundation.dart';

class StartupTrace {
  StartupTrace._();

  static final Stopwatch _clock = Stopwatch()..start();
  static int _seq = 0;

  static void log(String scope, String message) {
    final ms = _clock.elapsedMilliseconds.toString().padLeft(5, '0');
    final seq = (++_seq).toString().padLeft(3, '0');
    debugPrint('[STARTUP +${ms}ms #$seq][$scope] $message');
  }
}