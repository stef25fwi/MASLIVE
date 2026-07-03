import 'dart:collection';

import 'package:flutter/foundation.dart';

class DebugLogEntry {
  const DebugLogEntry({
    required this.timestamp,
    required this.scope,
    required this.message,
    required this.level,
    this.stackTrace,
  });

  final DateTime timestamp;
  final String scope;
  final String message;
  final String level;
  final String? stackTrace;

  bool get isFailure {
    final normalized = message.toLowerCase();
    return level == 'ERROR' ||
        normalized.contains('error') ||
        normalized.contains('exception') ||
        normalized.contains('failed') ||
        normalized.contains('fail') ||
        normalized.contains('❌') ||
        normalized.contains('⚠️');
  }

  String formatForCopy() {
    final buffer = StringBuffer()
      ..write('[${_formatTimestamp(timestamp)}][$level][$scope] ')
      ..write(message);
    if (stackTrace != null && stackTrace!.trim().isNotEmpty) {
      buffer
        ..write('\n')
        ..write(stackTrace!.trim());
    }
    return buffer.toString();
  }
}

class DebugLogBuffer {
  DebugLogBuffer._();

  static const int _maxEntries = 300;
  static final ListQueue<DebugLogEntry> _entries = ListQueue<DebugLogEntry>();
  static DebugPrintCallback? _previousDebugPrint;
  static bool _installed = false;
  static String _activeScope = 'GLOBAL';

  static void install() {
    if (_installed) return;
    _installed = true;
    _previousDebugPrint = debugPrint;
    debugPrint = _captureDebugPrint;
  }

  static void setActiveScope(String scope) {
    final trimmed = scope.trim();
    if (trimmed.isEmpty) return;
    _activeScope = trimmed;
  }

  static void clearActiveScope() {
    _activeScope = 'GLOBAL';
  }

  static void log(String message, {String level = 'INFO', String? scope}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    _append(
      DebugLogEntry(
        timestamp: DateTime.now(),
        scope: (scope?.trim().isNotEmpty ?? false)
            ? scope!.trim()
            : _activeScope,
        message: trimmed,
        level: level,
      ),
    );
  }

  static void logError(Object error, [StackTrace? stackTrace, String? scope]) {
    _append(
      DebugLogEntry(
        timestamp: DateTime.now(),
        scope: (scope?.trim().isNotEmpty ?? false)
            ? scope!.trim()
            : _activeScope,
        message: error.toString(),
        level: 'ERROR',
        stackTrace: stackTrace?.toString(),
      ),
    );
  }

  static List<DebugLogEntry> snapshot({String? scope}) {
    final entries = _entries.toList(growable: false);
    if (scope == null || scope.trim().isEmpty) {
      return entries;
    }
    final wantedScope = scope.trim();
    return entries
        .where((entry) => entry.scope == wantedScope)
        .toList(growable: false);
  }

  static String buildCopyText({String? scope}) {
    final entries = snapshot(scope: scope);
    if (entries.isEmpty) {
      return scope == null || scope.trim().isEmpty
          ? 'Aucun log disponible.'
          : 'Aucun log disponible pour $scope.';
    }

    return entries.map((entry) => entry.formatForCopy()).join('\n\n');
  }

  static void _captureDebugPrint(String? message, {int? wrapWidth}) {
    if (message != null && message.trim().isNotEmpty) {
      log(message);
    }
    _previousDebugPrint?.call(message, wrapWidth: wrapWidth);
  }

  static void _append(DebugLogEntry entry) {
    while (_entries.length >= _maxEntries) {
      _entries.removeFirst();
    }
    _entries.add(entry);
  }
}

String _formatTimestamp(DateTime timestamp) {
  final hours = timestamp.hour.toString().padLeft(2, '0');
  final minutes = timestamp.minute.toString().padLeft(2, '0');
  final seconds = timestamp.second.toString().padLeft(2, '0');
  final milliseconds = timestamp.millisecond.toString().padLeft(3, '0');
  return '$hours:$minutes:$seconds.$milliseconds';
}
