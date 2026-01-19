import 'package:flutter/material.dart';
import '../services/localization_service.dart';

class LanguageSidebar extends StatelessWidget {
  final VoidCallback? onLanguageChanged;

  const LanguageSidebar({super.key, this.onLanguageChanged});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService(),
      builder: (context, child) {
        final locService = LocalizationService();

        return Container(
          width: 80,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.92),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.language,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),

              // Pictogramme WC homme/femme
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Icon(
                  Icons.wc,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 24),

              // Language buttons
              _LanguageButton(
                label: 'FR',
                isSelected: locService.language == AppLanguage.fr,
                onPressed: () {
                  locService.setLanguage(AppLanguage.fr);
                  onLanguageChanged?.call();
                },
              ),
              const SizedBox(height: 12),
              _LanguageButton(
                label: 'EN',
                isSelected: locService.language == AppLanguage.en,
                onPressed: () {
                  locService.setLanguage(AppLanguage.en);
                  onLanguageChanged?.call();
                },
              ),
              const SizedBox(height: 12),
              _LanguageButton(
                label: 'ES',
                isSelected: locService.language == AppLanguage.es,
                onPressed: () {
                  locService.setLanguage(AppLanguage.es);
                  onLanguageChanged?.call();
                },
              ),
              const Spacer(),

              // Current language info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(height: 6),
                    Text(
                      locService.languageCode.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _LanguageButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? Colors.orange : Colors.white.withValues(alpha: 0.1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pour utiliser la traduction partout
extension Translations on BuildContext {
  String tr(String key) => AppLocalizations().translate(key);
}
