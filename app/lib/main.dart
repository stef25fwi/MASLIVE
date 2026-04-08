import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'admin/admin_main_dashboard.dart';
import 'admin/admin_circuits_page.dart';
import 'admin/admin_moderation_page.dart';
import 'admin/business_requests_page.dart';
import 'admin/category_management_page.dart';
import 'admin/circuit_wizard_entry_page.dart';
import 'admin/commerce_analytics_page.dart';
import 'admin/map_projects_library_page.dart';
import 'admin/map_project_wizard_entry_page.dart';
import 'admin/marketmap_debug_page.dart';
import 'admin/mapmarket_projects_page.dart';
import 'admin/role_management_page.dart';
import 'admin/super_admin_space.dart';
import 'commerce_module_single_file.dart';
import 'features/map_style/presentation/pages/mapbox_style_studio_page.dart';
import 'features/media_marketplace/presentation/pages/media_marketplace_pages.dart';
import 'features/shop/pages/media_photo_shop_page.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'pages/account_admin_page.dart';
import 'pages/account_page.dart';
import 'pages/app_shell.dart';
import 'pages/business_account_page.dart';
import 'pages/business_request_page.dart';
import 'pages/cart/unified_cart_page.dart';
import 'pages/circuit_calculs_validation_page.dart';
import 'pages/circuit_draw_page.dart';
import 'pages/circuit_editor_workflow_page.dart';
import 'pages/circuit_import_export_page.dart';
import 'pages/circuit_save_page.dart';
import 'pages/default_map_page.dart';
import 'pages/favorites_page.dart';
import 'pages/group/admin_group_dashboard_page.dart';
import 'pages/group/group_export_page.dart';
import 'pages/group/group_map_live_page.dart';
import 'pages/group/group_track_history_page.dart';
import 'pages/group/tracker_group_profile_page.dart';
import 'pages/group_member_page.dart';
import 'pages/group_profile_page.dart';
import 'pages/group_shop_page.dart';
import 'pages/home_map_page_3d.dart';
import 'pages/login_page.dart';
import 'pages/map_admin_editor_page.dart';
import 'pages/mapbox_web_map_page.dart';
import 'pages/orders_page.dart';
import 'pages/paywall_page.dart';
import 'pages/pending_products_page.dart';
import 'pages/public/marketmap_public_viewer_page.dart';
import 'pages/purchase_history_page.dart';
import 'pages/role_router_page.dart';
import 'pages/search_page.dart';
import 'pages/seller/seller_inbox_page.dart';
import 'pages/seller/seller_order_detail_page.dart';
import 'pages/shop/storex_reviews_and_success_pages.dart';
import 'pages/splash_wrapper_page.dart';
import 'pages/storex_shop_page.dart';
import 'pages/tracking_live_page.dart';
import 'pages/commerce/create_media_page.dart';
import 'pages/commerce/create_product_page.dart';
import 'pages/commerce/my_submissions_page.dart';
import 'providers/cart_provider.dart';
import 'route_style_pro/ui/route_style_wizard_pro_page.dart';
import 'services/cart_checkout_service.dart';
import 'services/cart_service.dart';
import 'services/language_service.dart';
import 'services/localization_service.dart' show LocalizationService;
import 'services/mapbox_token_service.dart';
import 'services/notifications_service.dart';
import 'services/premium_service.dart';
import 'session/session_controller.dart';
import 'session/session_scope.dart';
import 'ui/theme/maslive_theme.dart';
import 'ui/widgets/honeycomb_background.dart';
import 'utils/startup_trace.dart';
import 'widgets/admin_route_guard.dart';
import 'widgets/localized_app.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
String? _lastStartupFatalError;

String? _routeQueryParam(String key) {
  final direct = Uri.base.queryParameters[key];
  if (direct != null && direct.trim().isNotEmpty) {
    return direct.trim();
  }

  final fragment = Uri.base.fragment;
  final queryIndex = fragment.indexOf('?');
  if (queryIndex == -1 || queryIndex == fragment.length - 1) {
    return null;
  }

  try {
    final query = fragment.substring(queryIndex + 1);
    final value = Uri.splitQueryString(query)[key];
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  } catch (_) {
    return null;
  }
}

void _reportStartupFatal(Object error, [StackTrace? stackTrace]) {
  final message = error.toString();
  _lastStartupFatalError = message;
  StartupTrace.log('BOOT', 'fatal startup error: $message');
  debugPrint('❌ Startup fatal error: $message');
  if (stackTrace != null) {
    debugPrint('$stackTrace');
  }
}

void _installStartupErrorHandling() {
  FlutterError.onError = (details) {
    _reportStartupFatal(details.exception, details.stack);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _reportStartupFatal(error, stackTrace);
    return false;
  };

  ErrorWidget.builder = (details) {
    final message = _lastStartupFatalError ?? details.exceptionAsString();
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Erreur de demarrage MASLIVE',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };
}

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _installStartupErrorHandling();
    StartupTrace.log('MAIN', 'WidgetsFlutterBinding initialized');

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

    StartupTrace.log('MAIN', 'runApp(_BootstrapRoot)');
    runApp(const _BootstrapRoot());
  }, (error, stackTrace) => _reportStartupFatal(error, stackTrace));
}

class _BootstrapRoot extends StatefulWidget {
  const _BootstrapRoot();

  @override
  State<_BootstrapRoot> createState() => _BootstrapRootState();
}

class _BootstrapRootState extends State<_BootstrapRoot> {
  final SessionController _session = SessionController();
  Future<void>? _backgroundBootstrap;

  @override
  void initState() {
    super.initState();
    StartupTrace.log('BOOT', 'initState');
    _ensureBaselineServices();
    _startBootstrap();
  }

  void _ensureBaselineServices() {
    if (!Get.isRegistered<LanguageService>()) {
      Get.put(LanguageService());
      StartupTrace.log('BOOT', 'baseline LanguageService registered');
    }
  }

  void _startBootstrap() {
    _backgroundBootstrap ??= _bootstrapInBackground();
    unawaited(_backgroundBootstrap);
  }

  Future<void> _bootstrapInBackground() async {
    StartupTrace.log('BOOT', 'background bootstrap start');

    final firebaseReady = await _initializeFirebase();

    if (firebaseReady) {
      _startFirebaseDependentServices();
    }

    await Future.wait<void>([
      _initializeStripe(),
      _warmMapboxToken(),
      _initializeLanguageService(),
      _initializePremiumService(firebaseReady),
    ]);

    StartupTrace.log('BOOT', 'background bootstrap complete');
  }

  Future<bool> _initializeFirebase() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        StartupTrace.log(
          'FIREBASE',
          'initializeApp skipped already initialized',
        );
        return true;
      }

      StartupTrace.log('FIREBASE', 'initializeApp start');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      StartupTrace.log('FIREBASE', 'initializeApp success');
      return true;
    } catch (error, stackTrace) {
      StartupTrace.log('FIREBASE', 'initializeApp failed: $error');
      debugPrint('❌ Bootstrap: Firebase.initializeApp failed: $error');
      debugPrint('$stackTrace');
      return Firebase.apps.isNotEmpty;
    }
  }

  void _startFirebaseDependentServices() {
    try {
      _session.start();
      StartupTrace.log('BOOT', 'SessionController started');
    } catch (error) {
      debugPrint('⚠️ Bootstrap: SessionController.start skipped: $error');
    }

    try {
      CartService.instance.start();
      StartupTrace.log('BOOT', 'CartService started');
    } catch (error) {
      debugPrint('⚠️ Bootstrap: CartService.start skipped: $error');
    }

    try {
      NotificationsService.instance.start(navigatorKey: _rootNavigatorKey);
      StartupTrace.log('BOOT', 'NotificationsService started');
    } catch (error) {
      debugPrint('⚠️ Bootstrap: NotificationsService.start skipped: $error');
    }
  }

  Future<void> _initializeStripe() async {
    if (kIsWeb) {
      return;
    }

    const stripePublishableKey = String.fromEnvironment(
      'STRIPE_PUBLISHABLE_KEY',
      defaultValue: '',
    );
    if (stripePublishableKey.isEmpty) {
      debugPrint(
        '⚠️ Bootstrap: STRIPE_PUBLISHABLE_KEY missing, Stripe skipped',
      );
      return;
    }

    try {
      Stripe.publishableKey = stripePublishableKey;
      await Stripe.instance.applySettings().timeout(const Duration(seconds: 4));
      StartupTrace.log('STRIPE', 'applySettings success');
    } catch (error) {
      StartupTrace.log('STRIPE', 'applySettings failed: $error');
      debugPrint('⚠️ Bootstrap: Stripe applySettings skipped: $error');
    }
  }

  Future<void> _warmMapboxToken() async {
    try {
      StartupTrace.log('MAPBOX', 'warmUp start');
      await MapboxTokenService.warmUp().timeout(const Duration(seconds: 4));
      StartupTrace.log(
        'MAPBOX',
        'warmUp success source=${MapboxTokenService.cachedSource} len=${MapboxTokenService.cachedToken.length}',
      );
    } catch (error) {
      StartupTrace.log('MAPBOX', 'warmUp failed: $error');
      debugPrint('⚠️ Bootstrap: MapboxTokenService.warmUp skipped: $error');
    }
  }

  Future<void> _initializeLanguageService() async {
    try {
      final languageService = Get.find<LanguageService>();
      await languageService.init().timeout(const Duration(seconds: 3));
      StartupTrace.log(
        'LANG',
        'LanguageService init success locale=${languageService.locale.languageCode}',
      );
    } catch (error) {
      StartupTrace.log('LANG', 'LanguageService init failed: $error');
      debugPrint('⚠️ Bootstrap: LanguageService init fallback: $error');
      if (!Get.isRegistered<LanguageService>()) {
        Get.put(LanguageService());
      }
    }
  }

  Future<void> _initializePremiumService(bool firebaseReady) async {
    if (!firebaseReady) {
      StartupTrace.log('PREMIUM', 'init skipped firebase unavailable');
      return;
    }

    const revenueCatApiKey = String.fromEnvironment(
      'RC_API_KEY',
      defaultValue: 'REVENUECAT_PUBLIC_SDK_KEY_HERE',
    );

    if (!kIsWeb &&
        kReleaseMode &&
        PremiumService.isPlaceholderApiKey(revenueCatApiKey)) {
      debugPrint(
        '⚠️ Bootstrap: RC_API_KEY missing or placeholder in native release, PremiumService skipped',
      );
      return;
    }

    try {
      await PremiumService.instance
          .init(revenueCatApiKey: revenueCatApiKey, entitlementId: 'premium')
          .timeout(const Duration(seconds: 8));
      StartupTrace.log('PREMIUM', 'PremiumService init success');
    } catch (error) {
      StartupTrace.log('PREMIUM', 'PremiumService init failed: $error');
      debugPrint('⚠️ Bootstrap: PremiumService init skipped: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasLiveApp(session: _session);
  }
}

class MasLiveApp extends StatelessWidget {
  const MasLiveApp({super.key, required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      notifier: session,
      child: ChangeNotifierProvider<CartProvider>.value(
        value: CartProvider.instance..start(),
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
                '/': (_) =>
                    kIsWeb ? const DefaultMapPage() : const HomeMapPage3D(),
                '/map-web': (_) => const DefaultMapPage(),
                '/mapbox-web': (_) => const MapboxWebMapPage(),
                '/map-3d': (_) => const MapboxWebMapPage(),
                '/account-ui': (_) => const AccountUiPage(),
                '/shop-ui': (_) =>
                    const StorexShopPage(shopId: 'global', groupId: 'MASLIVE'),
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
                '/admin/commerce': (_) => AdminRouteGuard(
                  child: ProductManagementPage(shopId: 'global'),
                ),
                '/boutique': (_) =>
                    const StorexShopPage(shopId: 'global', groupId: 'MASLIVE'),
                '/boutique-photo': (_) => const MediaPhotoShopPage(),
                StorexRoutes.paymentComplete: (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments;
                  if (args is PaymentCompleteArgs) {
                    return PaymentCompletePage(
                      orderCode: args.orderCode,
                      continueToRoute: args.continueToRoute,
                    );
                  }
                  return const _RouteArgsErrorPage(
                    routeName: StorexRoutes.paymentComplete,
                  );
                },
                StorexRoutes.reviews: (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments;
                  if (args is ReviewsArgs) {
                    return ReviewsPage(
                      productId: args.productId,
                      productTitle: args.productTitle,
                    );
                  }
                  return const _RouteArgsErrorPage(
                    routeName: StorexRoutes.reviews,
                  );
                },
                StorexRoutes.addReview: (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments;
                  if (args is AddReviewArgs) {
                    return AddReviewPage(
                      productId: args.productId,
                      productTitle: args.productTitle,
                    );
                  }
                  return const _RouteArgsErrorPage(
                    routeName: StorexRoutes.addReview,
                  );
                },
                StorexRoutes.orderTracker: (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments;
                  if (args is OrderTrackerArgs) {
                    return OrderTrackerPage(orderId: args.orderId);
                  }
                  return const _RouteArgsErrorPage(
                    routeName: StorexRoutes.orderTracker,
                  );
                },
                '/account': (_) => const AccountAndAdminPage(),
                '/account-admin': (_) => const AccountAndAdminPage(),
                '/orders': (_) => const OrdersPage(),
                '/seller-inbox': (_) => const SellerInboxPage(),
                '/seller-order': (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments;
                  final orderId = args is String ? args : null;
                  if (orderId == null || orderId.trim().isEmpty) {
                    return const _RouteArgsErrorPage(
                      routeName: '/seller-order',
                    );
                  }
                  return SellerOrderDetailPage(orderId: orderId);
                },
                '/map-admin': (_) =>
                    const AdminRouteGuard(child: MapAdminEditorPage()),
                '/group-member': (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
                  final groupId = args != null
                      ? args['groupId'] as String?
                      : null;
                  return GroupMemberPage(groupId: groupId);
                },
                '/admin': (_) =>
                    const AdminRouteGuard(child: AdminMainDashboard()),
                '/admin/circuits': (_) =>
                    const AdminRouteGuard(child: AdminCircuitsPage()),
                '/admin/track-editor': (_) =>
                    const AdminRouteGuard(child: CircuitEditorWorkflowPage()),
                '/admin/map-library': (_) =>
                    const AdminRouteGuard(child: MapProjectsLibraryPage()),
                '/admin/mapmarket': (_) =>
                    const AdminRouteGuard(child: MapMarketProjectsPage()),
                '/admin/mapmarket/wizard': (_) =>
                    const AdminRouteGuard(child: MapProjectWizardEntryPage()),
                '/admin/marketmap-debug': (_) =>
                    const AdminRouteGuard(child: MarketMapDebugPage()),
                '/admin/circuit-wizard': (_) =>
                    const AdminRouteGuard(child: CircuitWizardEntryPage()),
                '/admin/mapbox-style-studio': (_) =>
                    const AdminRouteGuard(child: MapboxStyleStudioPage()),
                '/admin/route-style-pro': (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments;
                  if (args is RouteStyleProArgs) {
                    return AdminRouteGuard(
                      child: RouteStyleWizardProPage(
                        projectId: args.projectId,
                        circuitId: args.circuitId,
                        initialRoute: args.initialRoute,
                        initialStyleUrl: args.initialStyleUrl,
                      ),
                    );
                  }
                  return const AdminRouteGuard(
                    child: RouteStyleWizardProPage(),
                  );
                },
                '/admin/superadmin': (_) =>
                    const AdminRouteGuard(child: SuperAdminSpace()),
                '/admin/categories': (_) =>
                    const AdminRouteGuard(child: CategoryManagementPage()),
                '/admin/roles': (_) =>
                    const AdminRouteGuard(child: RoleManagementPage()),
                '/login': (_) => const LoginPage(),
                '/tracking': (_) => const TrackingLivePage(),
                '/search': (_) => const SearchPage(),
                '/circuit-import-export': (_) =>
                    const CircuitImportExportPage(),
                '/circuit-calculs': (_) => const CircuitCalculsValidationPage(),
                '/circuit-save': (_) => const CircuitSavePage(),
                '/circuit-draw': (_) => const CircuitDrawPage(),
                '/favorites': (_) => const FavoritesPage(),
                '/cart': (_) => const UnifiedCartPage(),
                '/paywall': (_) => const PaywallPage(),
                '/pending-products': (_) => const PendingProductsPage(),
                '/purchase-history': (_) => const PurchaseHistoryPage(),
                '/business': (_) => const BusinessAccountPage(),
                '/business-request': (_) => const BusinessRequestPage(),
                '/admin/business-requests': (_) =>
                    const AdminRouteGuard(child: BusinessRequestsPage()),
                '/commerce/create-product': (_) => const CreateProductPage(),
                '/commerce/create-media': (_) => const CreateMediaPage(),
                '/commerce/my-submissions': (_) => const MySubmissionsPage(),
                '/admin/moderation': (_) =>
                    const AdminRouteGuard(child: AdminModerationPage()),
                '/admin/commerce-analytics': (_) =>
                    const AdminRouteGuard(child: CommerceAnalyticsPage()),
                '/media-marketplace': (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments;
                  int initialTabIndex = 0;
                  if (args is Map) {
                    final countryId = args['countryId'] as String?;
                    final countryName = args['countryName'] as String?;
                    final eventId = args['eventId'] as String?;
                    final eventName = args['eventName'] as String?;
                    final circuitId = args['circuitId'] as String?;
                    final circuitName = args['circuitName'] as String?;
                    final photographerId = args['photographerId'] as String?;
                    final ownerUid = args['ownerUid'] as String?;
                    final initialTab = args['initialTab'];
                    if (initialTab is int) {
                      initialTabIndex = initialTab;
                    } else if (initialTab is String) {
                      switch (initialTab) {
                        case 'cart':
                          initialTabIndex = 1;
                          break;
                        case 'downloads':
                          initialTabIndex = 2;
                          break;
                        case 'photographer':
                          initialTabIndex = 3;
                          break;
                        default:
                          initialTabIndex = 0;
                      }
                    }
                    return MediaMarketplaceEntryPage(
                      countryId: countryId,
                      countryName: countryName,
                      eventId: eventId,
                      eventName: eventName,
                      circuitId: circuitId,
                      circuitName: circuitName,
                      photographerId: photographerId,
                      ownerUid: ownerUid,
                      initialTabIndex: initialTabIndex,
                    );
                  }
                  return const MediaMarketplaceEntryPage();
                },
                '/media-marketplace/cart': (_) => const UnifiedCartPage(),
                '/media-marketplace/success': (_) =>
                    _MediaMarketplaceCheckoutReturnPage(
                      succeeded: true,
                      orderId: _routeQueryParam('orderId'),
                    ),
                '/media-marketplace/cancel': (_) =>
                    _MediaMarketplaceCheckoutReturnPage(
                      succeeded: false,
                      orderId: _routeQueryParam('orderId'),
                    ),
                '/media-marketplace/downloads': (_) =>
                    const MediaDownloadsPage(),
                '/media-marketplace/photographer': (_) =>
                    const PhotographerDashboardPage(),
                '/media-marketplace/subscription': (_) =>
                    const PhotographerSubscriptionPage(),
                '/admin/media-marketplace/moderation': (_) =>
                    const AdminRouteGuard(child: AdminModerationQueuePage()),
                '/public/marketmap': (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments;
                  if (args is Map) {
                    final countryId = args['countryId'] as String?;
                    final eventId = args['eventId'] as String?;
                    final initialCircuitId =
                        args['initialCircuitId'] as String?;
                    final accessToken = args['accessToken'] as String?;

                    if (countryId != null && eventId != null) {
                      return MarketMapPublicViewerPage(
                        countryId: countryId,
                        eventId: eventId,
                        initialCircuitId: initialCircuitId,
                        accessToken: accessToken,
                      );
                    }
                  }
                  return const _RouteArgsErrorPage(
                    routeName: '/public/marketmap',
                  );
                },
                '/group-admin': (_) => const AdminGroupDashboardPage(),
                '/group-tracker': (_) => const TrackerGroupProfilePage(),
                '/group-live': (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
                  final adminGroupId =
                      (args?['adminGroupId'] as String?) ?? '000000';
                  return GroupMapLivePage(adminGroupId: adminGroupId);
                },
                '/group-history': (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
                  final adminGroupId =
                      (args?['adminGroupId'] as String?) ?? '000000';
                  final uid = args?['uid'] as String?;
                  return GroupTrackHistoryPage(
                    adminGroupId: adminGroupId,
                    uid: uid,
                  );
                },
                '/group-export': (ctx) {
                  final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
                  final adminGroupId =
                      (args?['adminGroupId'] as String?) ?? '000000';
                  final uid = args?['uid'] as String?;
                  return GroupExportPage(adminGroupId: adminGroupId, uid: uid);
                },
              },
              onGenerateRoute: (settings) {
                return null;
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
      ),
    );
  }
}

class _RouteArgsErrorPage extends StatelessWidget {
  const _RouteArgsErrorPage({required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Erreur: arguments manquants pour la route $routeName',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _MediaMarketplaceCheckoutReturnPage extends StatefulWidget {
  const _MediaMarketplaceCheckoutReturnPage({
    required this.succeeded,
    this.orderId,
  });

  final bool succeeded;
  final String? orderId;

  @override
  State<_MediaMarketplaceCheckoutReturnPage> createState() =>
      _MediaMarketplaceCheckoutReturnPageState();
}

class _MediaMarketplaceCheckoutReturnPageState
    extends State<_MediaMarketplaceCheckoutReturnPage> {
  @override
  void initState() {
    super.initState();
    if (!widget.succeeded) {
      unawaited(CartCheckoutService.releaseMediaCheckoutLock());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.succeeded ? 'Paiement confirme' : 'Paiement annule';
    final message = widget.succeeded
        ? 'Votre commande media a ete prise en compte.'
        : 'Votre panier media a ete conserve. Vous pouvez reprendre le checkout quand vous voulez.';
    final actionLabel = widget.succeeded
        ? 'Voir mes telechargements'
        : 'Retour au panier';
    final actionRoute = widget.succeeded
        ? '/media-marketplace/downloads'
        : '/media-marketplace/cart';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  widget.succeeded
                      ? Icons.check_circle_outline
                      : Icons.shopping_cart_outlined,
                  size: 56,
                  color: widget.succeeded
                      ? const Color(0xFF0F9D58)
                      : const Color(0xFF2563EB),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if ((widget.orderId ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Commande: ${widget.orderId!.trim()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil(actionRoute, (route) => false);
                  },
                  child: Text(actionLabel),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/media-marketplace',
                      (route) => false,
                    );
                  },
                  child: const Text('Retour au media marketplace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
