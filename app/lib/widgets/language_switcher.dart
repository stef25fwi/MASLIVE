import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../services/language_service.dart';

/// Icône de sélecteur de langue dans l'AppBar
class LanguageSwitcher extends StatelessWidget {
  final LanguageService languageService = Get.find<LanguageService>();

  LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopupMenuButton<String>(
        icon: const Icon(Icons.language),
        tooltip: AppLocalizations.of(context)!.changeLanguage,
        onSelected: (languageCode) async {
          await languageService.changeLanguage(languageCode);
          
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.languageChanged(
                  languageService.getLanguageName(languageCode),
                ),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        itemBuilder: (BuildContext context) {
          final languages = languageService.getAvailableLanguages();
          return languages.map((lang) {
            final code = lang['code']!;
            final name = lang['name']!;
            final flag = lang['flag']!;
            final isSelected = languageService.currentLanguageCode == code;
            
            return PopupMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Text(name),
                  if (isSelected) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: 18,
                    ),
                  ],
                ],
              ),
            );
          }).toList();
        },
      ),
    );
  }
}

/// Page complète de sélection de langue
class LanguageSelectionPage extends StatelessWidget {
  final LanguageService languageService = Get.find<LanguageService>();

  LanguageSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final languages = languageService.getAvailableLanguages();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectLanguage),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final lang = languages[index];
          final code = lang['code']!;
          final name = lang['name']!;
          final flag = lang['flag']!;
          final isSelected = languageService.currentLanguageCode == code;
          
          return Obx(
            () => Card(
              elevation: isSelected ? 4 : 0,
              color: isSelected
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
              child: ListTile(
                leading: Text(
                  flag,
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      )
                    : null,
                onTap: () async {
                  await languageService.changeLanguage(code);
                  if (!context.mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.languageChanged(name),
                      ),
                    ),
                  );
                  
                  // Retour à la page précédente
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dialogue simple de sélection de langue
class LanguageSelectionDialog extends StatelessWidget {
  final LanguageService languageService = Get.find<LanguageService>();

  LanguageSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final languages = languageService.getAvailableLanguages();
    
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.selectLanguage),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: languages.map((lang) {
          final code = lang['code']!;
          final name = lang['name']!;
          final flag = lang['flag']!;
          final isSelected = languageService.currentLanguageCode == code;
          
          return Obx(
            () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                onTap: () async {
                  await languageService.changeLanguage(code);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check, color: Colors.green),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
