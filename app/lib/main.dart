import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'session/session_controller.dart';
import 'session/session_scope.dart';
import 'services/localization_service.dart';
import 'widgets/localized_app.dart';
import 'pages/splash_screen.dart';
import 'pages/home_map_page.dart';
import 'pages/group_profile_page.dart';
import 'pages/group_shop_page.dart';
import 'pages/role_router_page.dart';
import 'pages/group_member_page.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/login_page.dart';
import 'pages/tracking_live_page.dart';
import 'pages/app_shell.dart';
import 'pages/cart_page.dart';
import 'pages/paywall_page.dart';
import 'pages/account_admin_page.dart';
import 'pages/account_page.dart';
import 'pages/orders_page.dart';
import 'pages/map_admin_editor_page.dart';
import 'pages/shop_page.dart';
import 'pages/pending_products_page.dart';
import 'admin/super_admin_space.dart';
import 'admin/category_management_page.dart';
import 'admin/role_management_page.dart';
import 'services/cart_service.dart';
import 'services/notifications_service.dart';
import 'services/premium_service.dart';
import 'ui/theme/maslive_theme.dart';
import 'ui/widgets/honeycomb_background.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.black,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: _rootNavigatorKey,
            theme: MasliveTheme.lightTheme,
            locale: Locale(LocalizationService().languageCode),
            initialRoute: '/splash',
            routes: {
              '/splash': (_) => const SplashScreen(),
              '/router': (_) => const RoleRouterPage(),
              '/': (_) => const HomeMapPage(),
              '/account-ui': (_) => const AccountUiPage(),
              '/shop-ui': (_) => const ShopUiPage(),
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
              '/admin': (_) => const AdminDashboardPage(),
              '/admin/superadmin': (_) => const SuperAdminSpace(),
              '/admin/categories': (_) => const CategoryManagementPage(),
              '/admin/roles': (_) => const RoleManagementPage(),
              '/login': (_) => const LoginPage(),
              '/tracking': (_) => const TrackingLivePage(),
              '/cart': (_) => const CartPage(),
              '/paywall': (_) => const PaywallPage(),
              '/pending-products': (_) => const PendingProductsPage(),
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
