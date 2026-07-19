import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/debug_log_buffer.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

/// Overlay global: enveloppe l'app et affiche un petit bouton flottant
/// « debug admin » sur tous les écrans. Il ouvre la console des logs
/// (toutes les requêtes / appels en arrière-plan capturés via debugPrint +
/// erreurs), avec mise en évidence des process en erreur.
///
/// Le bouton est déplaçable (drag) pour ne jamais bloquer le contenu.
class DebugAdminOverlay extends StatefulWidget {
  const DebugAdminOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<DebugAdminOverlay> createState() => _DebugAdminOverlayState();
}

class _DebugAdminOverlayState extends State<DebugAdminOverlay> {
  Offset? _pos; // position du bouton (null => coin bas-droit par défaut)

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    const btn = 46.0;
    final defaultPos = Offset(
      size.width - btn - 12,
      size.height - btn - media.padding.bottom - 96,
    );
    final pos = _pos ?? defaultPos;

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: pos.dx.clamp(4.0, size.width - btn - 4),
          top: pos.dy.clamp(media.padding.top + 4, size.height - btn - 4),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => setState(() {
                _pos = (_pos ?? defaultPos) + d.delta;
              }),
              onTap: () => showDebugAdminLogsSheet(context),
              child: Opacity(
                opacity: 0.9,
                child: Container(
                  width: btn,
                  height: btn,
                  decoration: BoxDecoration(
                    color: MasliveTokens.text,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bug_report_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Feuille affichant TOUS les logs (toutes portées) capturés en mémoire.
Future<void> showDebugAdminLogsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        builder: (context, scrollController) {
          return _DebugLogsView(scrollController: scrollController);
        },
      );
    },
  );
}

class _DebugLogsView extends StatefulWidget {
  const _DebugLogsView({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_DebugLogsView> createState() => _DebugLogsViewState();
}

class _DebugLogsViewState extends State<_DebugLogsView> {
  bool _errorsOnly = false;

  @override
  Widget build(BuildContext context) {
    var entries = DebugLogBuffer.snapshot();
    if (_errorsOnly) {
      entries = entries.where((e) => e.isFailure).toList(growable: false);
    }
    // Plus récents en haut.
    final ordered = entries.reversed.toList(growable: false);
    final errorCount = DebugLogBuffer.snapshot()
        .where((e) => e.isFailure)
        .length;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Debug admin — logs',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: errorCount > 0
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$errorCount err',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _errorsOnly ? 'Tout afficher' : 'Erreurs seulement',
                  icon: Icon(
                    _errorsOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
                    color: _errorsOnly ? const Color(0xFFF87171) : Colors.white70,
                  ),
                  onPressed: () => setState(() => _errorsOnly = !_errorsOnly),
                ),
                IconButton(
                  tooltip: 'Copier',
                  icon: const Icon(Icons.copy, color: Colors.white70),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: DebugLogBuffer.buildCopyText()),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logs copiés')),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Rafraîchir',
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: () => setState(() {}),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ordered.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun log capturé.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: ordered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final e = ordered[index];
                      final isErr = e.isFailure;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isErr
                              ? const Color(0x33B91C1C)
                              : MasliveTokens.text,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isErr
                                ? const Color(0xFFB91C1C)
                                : Colors.white12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${e.level} · ${e.scope}',
                                  style: TextStyle(
                                    color: isErr
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFF93C5FD),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _hhmmss(e.timestamp),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              e.message,
                              style: TextStyle(
                                color: isErr ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (e.stackTrace != null &&
                                e.stackTrace!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              SelectableText(
                                e.stackTrace!.trim(),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _hhmmss(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
