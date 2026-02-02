// ignore_for_file: unused_field, unused_element, dead_code

import 'package:flutter/material.dart';
import '../admin/create_circuit_assistant_page.dart';

class CircuitImportExportPage extends StatefulWidget {
  const CircuitImportExportPage({super.key});

  @override
  State<CircuitImportExportPage> createState() => _CircuitImportExportPageState();
}

class _CircuitImportExportPageState extends State<CircuitImportExportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text("Importer / Exporter (Legacy)", style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                "Outil legacy désactivé.\nUtilise le Wizard Circuit (MarketMap).",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateCircuitAssistantPage()),
                ),
                child: const Text("Ouvrir le Wizard Circuit"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widgets inutilisés mais conservés pour compilation
class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ImportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _FileCard extends StatelessWidget {
  final String file;
  final VoidCallback onDelete;

  const _FileCard({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2A37),
                  ),
                ),
                const SizedBox(height: 12),

                _ActionButton(
                  icon: Icons.download,
                  label: "Exporter en GPX",
                  color: const Color(0xFF34A853),
                  onPressed: _exportGpx,
                ),

                const SizedBox(height: 28),

                // Section Actions
                const Text(
                  "Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2A37),
                  ),
                ),
                const SizedBox(height: 12),

                _ActionButton(
                  icon: Icons.content_copy,
                  label: "Dupliquer le circuit",
                  color: const Color(0xFFF97316),
                  onPressed: _duplicateCircuit,
                ),

                const SizedBox(height: 28),

                // Section Fichiers
                if (_importedFiles.isNotEmpty) ...[
                  const Text(
                    "Fichiers importés",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2A37),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._importedFiles.map((file) => _FileCard(
                    file: file,
                    onDelete: () => _deleteFile(file),
                  )),
                ],
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ImportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2A37),
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final String file;
  final VoidCallback onDelete;

  const _FileCard({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.file_download_done, size: 20, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2A37),
                  ),
                ),
                Text(
                  "Importé avec succès",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 20, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
