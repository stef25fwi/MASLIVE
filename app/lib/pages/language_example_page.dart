import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_switcher.dart';
import '../services/language_service.dart';

/// Exemple d'intégration i18n dans une page
class LanguageExamplePage extends StatelessWidget {
  const LanguageExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.language),
        actions: [
          LanguageSwitcher(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Text(
              AppLocalizations.of(context)!.selectLanguage,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Langue actuelle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      languageService.getLanguageFlag(
                        languageService.currentLanguageCode,
                      ),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.selectedLanguage,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          languageService.getLanguageName(
                            languageService.currentLanguageCode,
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Liste des langues disponibles
            Text(
              AppLocalizations.of(context)!.language,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Obx(() {
              final languages = languageService.getAvailableLanguages();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: languages.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  final code = lang['code']!;
                  final name = lang['name']!;
                  final flag = lang['flag']!;
                  final isSelected = languageService.currentLanguageCode == code;

                  return ListTile(
                    leading: Text(flag, style: const TextStyle(fontSize: 24)),
                    title: Text(name),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    selected: isSelected,
                    onTap: () async {
                      await languageService.changeLanguage(code);
                    },
                  );
                },
              );
            }),
            const SizedBox(height: 24),

            // Boutons d'action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.language),
                label: Text(AppLocalizations.of(context)!.changeLanguage),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => LanguageSelectionDialog(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LanguageSelectionPage()),
                ),
                child: Text(AppLocalizations.of(context)!.selectLanguage),
              ),
            ),
            const SizedBox(height: 24),

            // Infos
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ℹ️ Information',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La langue sélectionnée est sauvegardée et persistera après redémarrage.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
