import 'package:flutter/material.dart';

class CategoryChipRow extends StatelessWidget {
  const CategoryChipRow({
    super.key,
    required this.labels,
    this.darkStyle = true,
    this.selectedIndex,
  });

  final List<String> labels;
  final bool darkStyle;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final Color bgDark = const Color(0xFF4A4D63);
    final Color bgLight = const Color(0xFFEFEFF1);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final bool isSelected = selectedIndex == null || selectedIndex == index;
          final Color background = darkStyle
              ? (isSelected ? bgDark : bgDark.withValues(alpha: 0.72))
              : (isSelected ? const Color(0xFFE8EAEF) : bgLight);
          final Color textColor = darkStyle
              ? Colors.white
              : (isSelected ? const Color(0xFF111111) : const Color(0xFF3F3F3F));

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              labels[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.1,
              ),
            ),
          );
        },
      ),
    );
  }
}
