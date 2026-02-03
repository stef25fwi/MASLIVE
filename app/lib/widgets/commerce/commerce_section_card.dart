import 'package:flutter/material.dart';
import '../../pages/commerce/create_product_page.dart';
import '../../pages/commerce/create_media_page.dart';
import '../../pages/commerce/my_submissions_page.dart';

/// Carte Commerce pour intégration dans les profils
class CommerceSectionCard extends StatelessWidget {
  const CommerceSectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, size: 28, color: Colors.deepPurple),
                const SizedBox(width: 12),
                const Text('Commerce', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildButton(
              context,
              icon: Icons.add_shopping_cart,
              label: 'Ajouter un article',
              color: Colors.deepPurple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateProductPage())),
            ),
            const SizedBox(height: 12),
            _buildButton(
              context,
              icon: Icons.add_photo_alternate,
              label: 'Ajouter un média',
              color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMediaPage())),
            ),
            const SizedBox(height: 12),
            _buildButton(
              context,
              icon: Icons.list_alt,
              label: 'Mes contenus',
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySubmissionsPage())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
