// FICHIER OBSOLÈTE - Utilisez admin_pois_simple_page.dart à la place
// Ce fichier est conservé pour référence mais ne doit pas être utilisé

import 'package:flutter/material.dart';

/// Page obsolète - Utiliser AdminPOIsSimplePage
@Deprecated('Utiliser AdminPOIsSimplePage à la place')
class AdminPOIsPageDeprecated extends StatelessWidget {
  const AdminPOIsPageDeprecated({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POIs (Obsolète)'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Cette page est obsolète',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Utilisez AdminPOIsSimplePage à la place'),
          ],
        ),
      ),
    );
  }
}
