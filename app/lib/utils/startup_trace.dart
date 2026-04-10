import 'package:flutter/foundation.dart';

class StartupTrace {
  StartupTrace._();

  static final Stopwatch _clock = Stopwatch()..start();
  static final Map<String, int> _marks = <String, int>{};
  static int _seq = 0;

  static void log(String scope, String message) {
    final ms = _clock.elapsedMilliseconds.toString().padLeft(5, '0');
    final seq = (++_seq).toString().padLeft(3, '0');
    debugPrint('[STARTUP +${ms}ms #$seq][$scope] $message');
  }

  static void mark(String name) {
    _marks[name] = _clock.elapsedMilliseconds;
  }

  static int? elapsedSince(String name) {
    final mark = _marks[name];
    if (mark == null) return null;
    return _clock.elapsedMilliseconds - mark;
  }
}