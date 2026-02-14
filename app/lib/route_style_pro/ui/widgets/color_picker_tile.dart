import 'package:flutter/material.dart';

class ColorPickerTile extends StatelessWidget {
  final String title;
  final Color color;
  final ValueChanged<Color> onChanged;

  const ColorPickerTile({
    super.key,
    required this.title,
    required this.color,
    required this.onChanged,
  });

  static const _swatches = <Color>[
    Color(0xFF1A73E8),
    Color(0xFF34A853),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF9333EA),
    Color(0xFF00FFB3),
    Color(0xFF111827),
    Color(0xFF0B1B2B),
    Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: InkWell(
        onTap: () => _openPicker(context),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
          ),
        ),
      ),
      onTap: () => _openPicker(context),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final hexController = TextEditingController(text: _toHexRgb(color));

    Color temp = color;

    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in _swatches)
                      InkWell(
                        onTap: () {
                          temp = c;
                          hexController.text = _toHexRgb(c);
                          (ctx as Element).markNeedsBuild();
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c.toARGB32() == temp.toARGB32()
                                  ? Colors.blue
                                  : Colors.black12,
                              width: c.toARGB32() == temp.toARGB32() ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: hexController,
                  decoration: const InputDecoration(
                    labelText: 'Hex (RRGGBB)',
                    prefixText: '#',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final parsed = _parseHexRgb(v);
                    if (parsed != null) {
                      temp = parsed;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, temp),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (picked != null) onChanged(picked);
  }

  String _toHexRgb(Color c) {
    // c.r/g/b sont 0..1 sur Color (dart:ui)
    final rr = ((c.r * 255).round())
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
    final gg = ((c.g * 255).round())
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
    final bb = ((c.b * 255).round())
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
    return '${rr.toUpperCase()}${gg.toUpperCase()}${bb.toUpperCase()}';
  }

  Color? _parseHexRgb(String v) {
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(v.trim());
    if (m == null) return null;
    final rgb = int.parse(m.group(1)!, radix: 16);
    return Color(0xFF000000 | rgb);
  }
}
