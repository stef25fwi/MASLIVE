from pathlib import Path

# 1) BuildContext across async gap
p = Path('app/lib/admin/poi_edit_popup.dart')
s = p.read_text()
old = """                              } catch (e) {
                                if (!mounted) return;
                                TopSnackBar.showMessage(
                                  context,
"""
new = """                              } catch (e) {
                                if (!context.mounted) return;
                                TopSnackBar.showMessage(
                                  context,
"""
if old not in s:
    raise SystemExit('poi_edit_popup async context block not found')
p.write_text(s.replace(old, new, 1))

# 2) Curly braces
p = Path('app/lib/admin/poi_marketmap_wizard_page.dart')
s = p.read_text()
old = """      if (v is String)
        return double.tryParse(v.trim().replaceAll(',', '.')) ?? fallback;
"""
new = """      if (v is String) {
        return double.tryParse(v.trim().replaceAll(',', '.')) ?? fallback;
      }
"""
if old not in s:
    raise SystemExit('poi wizard string parse block not found')
p.write_text(s.replace(old, new, 1))

# 3) Deprecated ReorderableListView callback
p = Path('app/lib/features/commerce/presentation/pages/product_management_page.dart')
s = p.read_text()
old = """                    onReorder: (oldIndex, newIndex) async {
                      final list = List<ProductImage>.from(imgs);
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
"""
new = """                    onReorderItem: (oldIndex, newIndex) async {
                      final list = List<ProductImage>.from(imgs);
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
"""
if old not in s:
    raise SystemExit('product image reorder block not found')
p.write_text(s.replace(old, new, 1))
