import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/debug_log_buffer.dart';

class AdminDebugLogsButton extends StatelessWidget {
  const AdminDebugLogsButton({super.key, this.scopeLabel});

  /// Scope à afficher. `null` => tous les logs (toutes pages confondues).
  final String? scopeLabel;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Logs de debug',
      icon: const Icon(Icons.bug_report_outlined, color: Colors.white),
      onPressed: () => showAdminDebugLogsSheet(context, scopeLabel: scopeLabel),
    );
  }
}

Future<void> showAdminDebugLogsSheet(
  BuildContext context, {
  String? scopeLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        builder: (context, scrollController) {
          final entries = DebugLogBuffer.snapshot(scope: scopeLabel);
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Debug admin',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                scopeLabel ?? 'Tous les logs',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copier tous les logs',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: DebugLogBuffer.buildCopyText(
                                  scope: scopeLabel,
                                ),
                              ),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Logs copiés')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                        IconButton(
                          tooltip: 'Fermer',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _CounterChip(
                          label: 'Total',
                          value: entries.length.toString(),
                        ),
                        const SizedBox(width: 8),
                        _CounterChip(
                          label: 'Échecs',
                          value: entries
                              .where((entry) => entry.isFailure)
                              .length
                              .toString(),
                          accentColor: const Color(0xFFB42318),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Aucun log pour cette page.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return _LogCard(entry: entry);
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({
    required this.label,
    required this.value,
    this.accentColor = const Color(0xFF1D2939),
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});

  final DebugLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final isFailure = entry.isFailure;
    final backgroundColor = isFailure ? const Color(0xFFFFF1F0) : Colors.white;
    final borderColor = isFailure
        ? const Color(0xFFFDA29B)
        : const Color(0xFFE5E7EB);
    final accentColor = isFailure
        ? const Color(0xFFB42318)
        : const Color(0xFF344054);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isFailure ? Icons.error_outline_rounded : Icons.notes_rounded,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.message,
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: isFailure ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copier cette ligne',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: entry.formatForCopy()),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Log copié')));
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SmallPill(text: entry.level, color: accentColor),
              _SmallPill(text: entry.scope, color: const Color(0xFF344054)),
              _SmallPill(
                text: _formatShortTime(entry.timestamp),
                color: const Color(0xFF475467),
              ),
            ],
          ),
          if (entry.stackTrace != null &&
              entry.stackTrace!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(
              entry.stackTrace!.trim(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatShortTime(DateTime timestamp) {
  final hours = timestamp.hour.toString().padLeft(2, '0');
  final minutes = timestamp.minute.toString().padLeft(2, '0');
  final seconds = timestamp.second.toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
