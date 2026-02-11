import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:masslive/pages/default_map_page.dart';
import 'package:masslive/services/language_service.dart';
import 'package:masslive/services/mapbox_token_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock LanguageService
class MockLanguageService extends GetxService implements LanguageService {
  @override
  Locale get locale => const Locale('fr');

  @override
  Rx<Locale> get localeRx => const Locale('fr').obs;
  
  @override
  String get currentLanguageCode => 'fr';
  
  @override
  Future<LanguageService> init() async => this;
  
  @override
  Future<void> changeLanguage(String languageCode) async {}
  
  // Stubs for other methods/properties if needed
  Map<String, String> get keys => {};

  void updateLocale(Locale value) {}

  @override
  String getLanguageName(String languageCode) => 'Français';

  @override
  String getLanguageFlag(String languageCode) => '🇫🇷';

  @override
  List<Map<String, String>> getAvailableLanguages() => [
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock Firebase Core manually to avoid transitive dependency import issues
    const MethodChannel channel = MethodChannel('plugins.flutter.io/firebase_core');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
       if (methodCall.method == 'Firebase#initializeCore') {
        return [
          {
            'name': '[DEFAULT]',
            'options': {
              'apiKey': '123',
              'appId': '123',
              'messagingSenderId': '123',
              'projectId': '123',
            },
            'pluginConstants': {},
          }
        ];
      }
      if (methodCall.method == 'Firebase#initializeApp') {
        return {
          'name': methodCall.arguments['appName'],
          'options': methodCall.arguments['options'],
          'pluginConstants': {},
        };
      }
      return null;
    });

    await Firebase.initializeApp();

    // Mock SharedPreferences for MapboxTokenService

    SharedPreferences.setMockInitialValues({});
    await MapboxTokenService.warmUp();
  });

  setUp(() {
    Get.reset();
    Get.put<LanguageService>(MockLanguageService());
  });

  testWidgets('DefaultMapPage shows expected fallback message', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Wrap in MaterialApp/Scaffold because DefaultMapPage expects it (it returns Scaffold)
    await tester.pumpWidget(
      const GetMaterialApp(
        home: DefaultMapPage(),
      ),
    );

    // Verify that the expected fallback is shown.
    // - VM tests (non-web): page displays a "web-only" message
    // - Chrome tests (web): without a token, page displays a "missing token" message
    if (kIsWeb) {
      expect(find.textContaining('Token Mapbox manquant'), findsOneWidget);
    } else {
      expect(find.text('Cette page est uniquement disponible sur Web.'), findsOneWidget);
    }
    expect(find.text('Carte par défaut'), findsOneWidget);
  });
}
