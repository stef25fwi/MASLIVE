# 🌍 Internationalisation (i18n) - Flutter MASLIVE

## 📋 Vue d'ensemble

L'application MASLIVE supporte 3 langues :
- 🇫🇷 **Français** (fr)
- 🇬🇧 **Anglais** (en)
- 🇪🇸 **Espagnol** (es)

## 🏗️ Architecture

### Structure des fichiers

```
lib/
├── l10n/                           # Dossier d'internationalisation
│   ├── app_fr.arb                 # Traductions français (template)
│   ├── app_en.arb                 # Traductions anglais
│   └── app_es.arb                 # Traductions espagnol
├── services/
│   └── language_service.dart      # Gestion des langues
├── widgets/
│   └── language_switcher.dart     # Sélecteur de langue UI
└── l10n.yaml                       # Configuration i18n
```

### Dépendances

```yaml
intl: ^0.19.0              # Framework i18n
get: ^4.6.6               # State management + GetX routing
shared_preferences: ^2.2.2 # Persistance des préférences
```

## 🚀 Utilisation

### 1️⃣ Accéder aux traductions

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Dans un widget
Text(AppLocalizations.of(context)!.hello)
```

### 2️⃣ Changer la langue

```dart
import 'package:get/get.dart';
import 'services/language_service.dart';

final languageService = Get.find<LanguageService>();
await languageService.changeLanguage('en'); // Passer à l'anglais
```

### 3️⃣ Ajouter un sélecteur de langue

**Option A : Icône dans l'AppBar**
```dart
import 'widgets/language_switcher.dart';

AppBar(
  title: Text('Mon App'),
  actions: [
    LanguageSwitcher(),
  ],
)
```

**Option B : Page complète**
```dart
import 'widgets/language_switcher.dart';

Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => LanguageSelectionPage()),
)
```

**Option C : Dialogue**
```dart
import 'widgets/language_switcher.dart';

showDialog(
  context: context,
  builder: (_) => LanguageSelectionDialog(),
)
```

## 📝 Ajouter/Modifier des traductions

### 1. Modifiez `app_fr.arb` (template)

```json
{
  "@@locale": "fr",
  "myKey": "Ma valeur en français",
  "greeting": "Bonjour {name}!",
  "@greeting": {
    "description": "Salutation à l'utilisateur",
    "placeholders": {
      "name": {
        "type": "String",
        "example": "Jean"
      }
    }
  }
}
```

### 2. Copiez les clés dans `app_en.arb` et `app_es.arb`

```json
{
  "@@locale": "en",
  "myKey": "My value in English",
  "greeting": "Hello {name}!",
  "@greeting": { ... }
}
```

### 3. Générez le code

```bash
cd app
flutter gen-l10n

# Ou laissez Flutter le faire automatiquement au build
flutter pub get
```

### 4. Utilisez en code

```dart
// Sans paramètres
Text(AppLocalizations.of(context)!.myKey)

// Avec paramètres
Text(AppLocalizations.of(context)!.greeting(name: 'Jean'))
```

## 🔄 Processus de sélection

### 1️⃣ Au démarrage
- L'app essaie de charger la langue sauvegardée (SharedPreferences)
- Sinon, utilise la langue du système (si supportée)
- Sinon, par défaut en français

### 2️⃣ À la sélection
- La langue est changée immédiatement dans l'UI
- Sauvegardée dans SharedPreferences
- Persiste après redémarrage

### 3️⃣ Message de confirmation
Un SnackBar s'affiche avec le message :
```
"Langue changée en Français" / "Language changed to English" / etc.
```

## 🎨 Sélecteur visuel

Le **LanguageSwitcher** affiche :
- 🎌 Drapeau emoji de chaque langue
- Nom localisé (Français, English, Español)
- ✅ Checkmark pour la langue active

## 📱 Exemple complet

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'l10n/app_localizations.dart';
import 'widgets/language_switcher.dart';
import 'services/language_service.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      locale: Get.find<LanguageService>().locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.appTitle),
          actions: [
            LanguageSwitcher(),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(AppLocalizations.of(context)!.selectLanguage),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => LanguageSelectionDialog(),
                  );
                },
                child: Text(AppLocalizations.of(context)!.changeLanguage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 🐛 Troubleshooting

### L'App Localizations n'est pas généré

```bash
cd app
flutter pub get
flutter gen-l10n --arb-dir=lib/l10n
```

### Les traductions ne changent pas

Vérifiez que :
1. Vous utilisez `AppLocalizations.of(context)!.key`
2. GetX est initialisé : `Get.putAsync(() => LanguageService().init())`
3. Vous avez redémarré l'app

### Erreur "Missing localization"

Assurez-vous que toutes les clés existent dans les 3 fichiers `.arb`

## 📦 Fichiers générés

Après `flutter gen-l10n`, les fichiers suivants sont générés :
- `lib/gen/l10n/app_localizations.dart` (classe principale)
- `lib/gen/l10n/app_localizations_*.dart` (traductions spécifiques)

**Note**: Ces fichiers sont auto-générés, ne les modifiez pas manuellement.

## 🔗 Ressources

- [Docs Flutter i18n](https://docs.flutter.dev/accessibility-and-localization/internationalization)
- [Intl package](https://pub.dev/packages/intl)
- [GetX documentation](https://github.com/jonataslaw/getx)
