import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'firebase_options.dart';
import 'session/session_controller.dart';
import 'session/session_scope.dart';
import 'services/localization_service.dart' show LocalizationService;
import 'services/language_service.dart';
import 'widgets/localized_app.dart';
import 'pages/splash_wrapper_page.dart';
import 'pages/home_map_page_web.dart';
import 'pages/group_profile_page.dart';
import 'pages/group_shop_page.dart';
import 'pages/role_router_page.dart';
import 'pages/group_member_page.dart';
import 'pages/login_page.dart';
import 'pages/tracking_live_page.dart';
import 'pages/app_shell.dart';
import 'pages/cart_page.dart';
import 'pages/paywall_page.dart';
import 'pages/account_admin_page.dart';
import 'pages/account_page.dart';
import 'pages/orders_page.dart';
import 'pages/map_admin_editor_page.dart';
import 'pages/shop_page_new.dart';
import 'pages/pending_products_page.dart';
import 'pages/search_page.dart';
import 'pages/circuit_import_export_page.dart';
import 'pages/circuit_calculs_validation_page.dart';
import 'pages/circuit_save_page.dart';
import 'pages/favorites_page.dart';
import 'pages/circuit_draw_page.dart';
import 'pages/purchase_history_page.dart';
import 'pages/business_account_page.dart';
import 'pages/business_request_page.dart';
import 'pages/mapbox_web_map_page.dart';
import 'pages/default_map_page.dart';
import 'admin/super_admin_space.dart';
import 'admin/category_management_page.dart';
import 'admin/role_management_page.dart';
import 'admin/admin_circuits_page.dart';
import 'admin/map_projects_library_page.dart';
import 'admin/business_requests_page.dart';
import 'admin/admin_main_dashboard.dart';
import 'admin/mapmarket_projects_page.dart';
import 'admin/map_project_wizard_entry_page.dart';
import 'admin/marketmap_debug_page.dart';
import 'services/cart_service.dart';
import 'services/notifications_service.dart';
import 'services/premium_service.dart';
import 'services/mapbox_token_service.dart';
import 'ui/theme/maslive_theme.dart';
import 'ui/widgets/honeycomb_background.dart';
import 'l10n/app_localizations.dart';
import 'pages/circuit_editor_workflow_page.dart';
import 'commerce_module_single_file.dart';
import 'pages/commerce/create_product_page.dart';
import 'pages/commerce/create_media_page.dart';
import 'pages/commerce/my_submissions_page.dart';
import 'admin/admin_moderation_page.dart';
import 'admin/commerce_analytics_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Initialiser le token Mapbox (charge depuis SharedPreferences si dispo)
  await MapboxTokenService.warmUp();

  // ✅ Initialiser le service de langue
  await Get.putAsync(() => LanguageService().init());

  // ✅ RevenueCat init (mets ta clé via --dart-define=RC_API_KEY=...)
  await PremiumService.instance.init(
    revenueCatApiKey: const String.fromEnvironment(
      'RC_API_KEY',
      defaultValue: 'REVENUECAT_PUBLIC_SDK_KEY_HERE',
    ),
    entitlementId: 'premium',
  );

  // ✅ Initialiser la session (auth listener)
  final session = SessionController()..start();

  // ✅ Initialiser le panier (sync Firestore si connecté)
  CartService.instance.start();

  // ✅ Notifications: synchronise le token FCM dans users/{uid}
  NotificationsService.instance.start(navigatorKey: _rootNavigatorKey);

  runApp(MasLiveApp(session: session));
}

class MasLiveApp extends StatelessWidget {
  const MasLiveApp({super.key, required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      notifier: session,
      child: ListenableBuilder(
        listenable: LocalizationService(),
        builder: (context, child) {
          return GetMaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: _rootNavigatorKey,
            theme: MasliveTheme.lightTheme,
            title: 'MASLIVE',
            locale: Get.find<LanguageService>().locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            initialRoute: '/splash',
            routes: {
              '/splash': (_) => const SplashWrapperPage(),
              '/router': (_) => const RoleRouterPage(),
              '/': (_) => const DefaultMapPage(),
              // '/map-legacy': (_) => const HomeMapPageV3(), // 🔄 Moved to legacy
              '/map-3d': (_) => const MapboxWebMapPage(), // Mapbox GL JS via HtmlElementView
              '/map-web': (_) =>
                  const HomeMapPageWeb(), // 🌐 Carte Web alternative (ancienne)
              // '/mapbox-google-light': (_) => const GoogleLightMapPage(), // Moved to legacy
              '/mapbox-web': (_) => const MapboxWebMapPage(), // Mapbox GL JS via HtmlElementView
              '/account-ui': (_) => const AccountUiPage(),
              '/shop-ui': (_) => const ShopPixelPerfectPage(),
              '/group-ui': (_) => const GroupProfilePage(groupId: 'demo'),
              '/app': (ctx) {
                final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
                final groupId = args != null
                    ? args['groupId'] as String?
                    : null;
                return AppShell(groupId: groupId ?? 'groupe_demo');
              },
              '/group': (_) => const GroupProfilePage(groupId: 'groupe_demo'),
              '/shop': (ctx) {
                final groupId =
                    ModalRoute.of(ctx)?.settings.arguments as String?;
                return GroupShopPage(groupId: groupId ?? 'groupe_demo');
              },
              '/admin/commerce': (_) => const ProductManagementPage(
                    shopId: 'global',
                  ),
              '/boutique': (ctx) {
                final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
                final shopId = (args?['shopId'] as String?) ?? 'global';
                final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                return BoutiquePage(shopId: shopId, userId: uid);
              },
              '/account': (_) => const AccountAndAdminPage(),
              '/account-admin': (_) => const AccountAndAdminPage(),
              '/orders': (_) => const OrdersPage(),
              '/map-admin': (_) => const MapAdminEditorPage(),
              '/group-member': (ctx) {
                final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
                final groupId = args != null
                    ? args['groupId'] as String?
                    : null;
                return GroupMemberPage(groupId: groupId);
              },
              '/admin': (_) => const AdminMainDashboard(),
              '/admin/circuits': (_) => const AdminCircuitsPage(),
              '/admin/track-editor': (_) => const CircuitEditorWorkflowPage(),
              '/admin/map-library': (_) => const MapProjectsLibraryPage(),
              '/admin/mapmarket': (_) => const MapMarketProjectsPage(),
              '/admin/mapmarket/wizard': (_) => const MapProjectWizardEntryPage(),
              '/admin/marketmap-debug': (_) => const MarketMapDebugPage(),
              '/admin/superadmin': (_) => const SuperAdminSpace(),
              '/admin/categories': (_) => const CategoryManagementPage(),
              '/admin/roles': (_) => const RoleManagementPage(),
              '/login': (_) => const LoginPage(),
              '/tracking': (_) => const TrackingLivePage(),
              '/search': (_) => const SearchPage(),
              '/circuit-import-export': (_) => const CircuitImportExportPage(),
              '/circuit-calculs': (_) => const CircuitCalculsValidationPage(),
              '/circuit-save': (_) => const CircuitSavePage(),
              '/circuit-draw': (_) => const CircuitDrawPage(),
              '/favorites': (_) => const FavoritesPage(),
              '/cart': (_) => const CartPage(),
              '/paywall': (_) => const PaywallPage(),
              '/pending-products': (_) => const PendingProductsPage(),
              '/purchase-history': (_) => const PurchaseHistoryPage(),
              '/business': (_) => const BusinessAccountPage(),
              '/business-request': (_) => const BusinessRequestPage(),
              '/admin/business-requests': (_) => const BusinessRequestsPage(),
              '/commerce/create-product': (_) => const CreateProductPage(),
              '/commerce/create-media': (_) => const CreateMediaPage(),
              '/commerce/my-submissions': (_) => const MySubmissionsPage(),
              '/admin/moderation': (_) => const AdminModerationPage(),
              '/admin/commerce-analytics': (_) => const CommerceAnalyticsPage(),
            },
            builder: (context, child) => HoneycombBackground(
              opacity: 0.08,
              child: LocalizedApp(
                showLanguageSidebar: true,
                child: child ?? const SizedBox(),
              ),
            ),
          );
        },
      ),
    );
  }
}
