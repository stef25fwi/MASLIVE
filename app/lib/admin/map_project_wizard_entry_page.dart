import 'package:flutter/material.dart';
import 'map_project_wizard_page.dart';

class MapProjectWizardEntryPage extends StatelessWidget {
  const MapProjectWizardEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final projectId = (args?['projectId'] ?? '').toString();

    if (projectId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('projectId manquant')),
      );
    }

    return MapProjectWizardPage(projectId: projectId);
  }
}
