import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../utils/debug_log_buffer.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

class AdminDebugLogsButton extends StatelessWidget {
  const AdminDebugLogsButton({super.key, this.scopeLabel});

  /// Scope à afficher. `null` => tous les logs (toutes pages confondues).
  final String? scopeLabel;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: IconButton(
        tooltip: 'Logs de debug',
        icon: const Icon(Icons.bug_report_outlined, color: Colors.white),
        onPressed: () {
          showAdminDebugLogsSheet(context, scopeLabel: scopeLabel);
        },
      ),
    );
  }
}

/// Ouvre les logs dans une vraie boîte de dialogue utilisant le navigateur
/// racine. Cette approche reste cliquable même lorsqu'une vue HTML/Mapbox est
/// affichée derrière la page sur Flutter Web.
Future<void> showAdminDebugLogsSheet(
  BuildContext context, {
  String? scopeLabel,
}) async {
  final entries = DebugLogBuffer.snapshot(scope: scopeLabel);

  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (dialogContext) {
      final screenSize = MediaQuery.sizeOf(dialogContext);
      final dialogWidth = screenSize.width < 720 ? screenSize.width - 24 : 680.0;
      final dialogHeight = screenSize.height < 760
          ? screenSize.height - 32
          : 720.0;

      return PointerInterceptor(
        child: Dialog(
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              children: <Widget>[
                _DialogHeader(
                  scopeLabel: scopeLabel,
                  entries: entries,
                  onClose: () => Navigator.of(
                    dialogContext,
                    rootNavigator: true,
                  ).pop(),
                  onCopyAll: () => _copyText(
                    dialogContext,
                    DebugLogBuffer.buildCopyText(scope: scopeLabel),
                    successMessage: 'Logs copiés',
                  ),
                ),
                const Divider(height: 1),
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
                          padding: const EdgeInsets.all(16),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (itemContext, index) {
                            return _LogCard(entry: entries[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _copyText(
  BuildContext context,
  String text, {
  required String successMessage,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(successMessage)));
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.scopeLabel,
    required this.entries,
    required this.onClose,
    required this.onCopyAll,
  });

  final String? scopeLabel;
  final List<DebugLogEntry> entries;
  final VoidCallback onClose;
  final VoidCallback onCopyAll;

  @override
  Widget build(BuildContext context) {
    final failureCount = entries.where((entry) => entry.isFailure).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.bug_report_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Debug admin',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${scopeLabel ?? 'Tous les logs'} · ${entries.length} log(s) · $failureCount échec(s)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onCopyAll,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copier'),
          ),
          IconButton(
            tooltip: 'Fermer',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
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
        : MasliveTokens.line;
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
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                isFailure ? Icons.error_outline_rounded : Icons.notes_rounded,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
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
                onPressed: () => _copyText(
                  context,
                  entry.formatForCopy(),
                  successMessage: 'Log copié',
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _SmallPill(text: entry.level, color: accentColor),
              _SmallPill(text: entry.scope, color: const Color(0xFF344054)),
              _SmallPill(
                text: _formatShortTime(entry.timestamp),
                color: const Color(0xFF475467),
              ),
            ],
          ),
          if (entry.stackTrace != null &&
              entry.stackTrace!.trim().isNotEmpty) ...<Widget>[
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
