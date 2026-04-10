import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

// ── Deferred: chargés à la demande (allège le bundle JS initial) ──
import 'admin/admin_main_dashboard.dart' deferred as _admMain;
import 'admin/admin_circuits_page.dart' deferred as _admCircuits;
import 'admin/admin_moderation_page.dart' deferred as _admModeration;
import 'admin/business_requests_page.dart' deferred as _admBizReq;
import 'admin/category_management_page.dart' deferred as _admCategories;
import 'admin/circuit_wizard_entry_page.dart' deferred as _admCircuitWiz;
import 'admin/commerce_analytics_page.dart' deferred as _admComAnalytics;
import 'admin/map_projects_library_page.dart' deferred as _admMapLib;
import 'admin/map_project_wizard_entry_page.dart' deferred as _admMapWiz;
import 'admin/marketmap_debug_page.dart' deferred as _admMarketDebug;
import 'admin/mapmarket_projects_page.dart' deferred as _admMapmarket;
import 'admin/role_management_page.dart' deferred as _admRoles;
import 'admin/super_admin_space.dart' deferred as _admSuper;
import 'commerce_module_single_file.dart' deferred as _commerce;
import 'features/map_style/presentation/pages/mapbox_style_studio_page.dart' deferred as _mapStyleStudio;
import 'features/media_marketplace/presentation/pages/media_marketplace_pages.dart' deferred as _mediaMarket;
import 'features/shop/pages/media_photo_shop_page.dart' deferred as _photoShop;
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
// ── Eager: léger, args/routes constants ──
import 'pages/shop/storex_route_args.dart';
import 'route_style_pro/ui/route_style_pro_args.dart';
// ── Eager: pages critiques au démarrage ──
import 'pages/default_map_page.dart';
import 'pages/splash_wrapper_page.dart';
// ── Deferred: toutes les autres pages (chargées à la demande) ──
import 'pages/account_admin_page.dart' deferred as _account;
import 'pages/account_page.dart' deferred as _accountUi;
import 'pages/app_shell.dart' deferred as _appShell;
import 'pages/business_account_page.dart' deferred as _bizAccount;
import 'pages/business_request_page.dart' deferred as _bizRequest;
import 'pages/cart/unified_cart_page.dart' deferred as _cart;
import 'pages/circuit_calculs_validation_page.dart' deferred as _circuitCalc;
import 'pages/circuit_draw_page.dart' deferred as _circuitDraw;
import 'pages/circuit_editor_workflow_page.dart' deferred as _circuitEditor;
import 'pages/circuit_import_export_page.dart' deferred as _circuitIO;
import 'pages/circuit_save_page.dart' deferred as _circuitSave;
import 'pages/favorites_page.dart' deferred as _favorites;
import 'pages/group/admin_group_dashboard_page.dart' deferred as _grpAdmin;
import 'pages/group/group_export_page.dart' deferred as _grpExport;
import 'pages/group/group_map_live_page.dart' deferred as _grpLive;
import 'pages/group/group_track_history_page.dart' deferred as _grpHistory;
import 'pages/group/tracker_group_profile_page.dart' deferred as _grpTracker;
import 'pages/group_member_page.dart' deferred as _grpMember;
import 'pages/group_profile_page.dart' deferred as _grpProfile;
import 'pages/group_shop_page.dart' deferred as _grpShop;
import 'pages/home_map_page_3d.dart' deferred as _home3d;
import 'pages/login_page.dart' deferred as _login;
import 'pages/map_admin_editor_page.dart' deferred as _mapAdmin;
import 'pages/mapbox_web_map_page.dart' deferred as _mapboxWeb;
import 'pages/orders_page.dart' deferred as _orders;
import 'pages/paywall_page.dart' deferred as _paywall;
import 'pages/pending_products_page.dart' deferred as _pendingProd;
import 'pages/public/marketmap_public_viewer_page.dart' deferred as _publicMap;
import 'pages/purchase_history_page.dart' deferred as _purchaseHist;
import 'pages/search_page.dart' deferred as _search;
import 'pages/seller/seller_inbox_page.dart' deferred as _sellerInbox;
import 'pages/seller/seller_order_detail_page.dart' deferred as _sellerOrder;
import 'pages/shop/storex_reviews_and_success_pages.dart' deferred as _storexReviews;
import 'pages/storex_shop_page.dart' deferred as _storexShop;
import 'pages/tracking_live_page.dart' deferred as _tracking;
import 'pages/commerce/create_media_page.dart' deferred as _createMedia;
import 'pages/commerce/create_product_page.dart' deferred as _createProduct;
import 'pages/commerce/my_submissions_page.dart' deferred as _mySubmissions;
import 'route_style_pro/ui/route_style_wizard_pro_page.dart' deferred as _routeStylePro;
import 'providers/cart_provider.dart';
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
  VoidCallback? _deferredWebBootstrapListener;
  bool _didStartDeferredWebBootstrap = false;

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
      _startImmediateFirebaseDependentServices();
      if (kIsWeb) {
        _scheduleDeferredWebBootstrap();
      } else {
        _startDeferredFirebaseDependentServices();
      }
    }

    final startupTasks = <Future<void>>[
      _initializeStripe(),
      _warmMapboxToken(),
      _initializeLanguageService(),
      if (!kIsWeb) _initializePremiumService(firebaseReady),
    ];

    await Future.wait<void>(startupTasks);

    if (kIsWeb && firebaseReady) {
      StartupTrace.log('BOOT', 'background bootstrap core complete (web)');
      return;
    }

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
      ).timeout(const Duration(seconds: 5));
      StartupTrace.log('FIREBASE', 'initializeApp success');
      return true;
    } catch (error, stackTrace) {
      StartupTrace.log('FIREBASE', 'initializeApp failed: $error');
      debugPrint('❌ Bootstrap: Firebase.initializeApp failed: $error');
      debugPrint('$stackTrace');
      return Firebase.apps.isNotEmpty;
    }
  }

  void _startImmediateFirebaseDependentServices() {
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
  }

  void _startDeferredFirebaseDependentServices() {
    try {
      NotificationsService.instance.start(navigatorKey: _rootNavigatorKey);
      StartupTrace.log('BOOT', 'NotificationsService started');
    } catch (error) {
      debugPrint('⚠️ Bootstrap: NotificationsService.start skipped: $error');
    }
  }

  void _scheduleDeferredWebBootstrap() {
    if (_didStartDeferredWebBootstrap) return;

    void scheduleStart() {
      if (_didStartDeferredWebBootstrap) return;
      _didStartDeferredWebBootstrap = true;

      final listener = _deferredWebBootstrapListener;
      if (listener != null) {
        mapReadyNotifier.removeListener(listener);
        _deferredWebBootstrapListener = null;
      }

      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        unawaited(_runDeferredWebBootstrap());
      });
    }

    StartupTrace.log('BOOT', 'web post-splash bootstrap deferred');

    if (mapReadyNotifier.value) {
      scheduleStart();
      return;
    }

    _deferredWebBootstrapListener = () {
      if (!mapReadyNotifier.value) return;
      scheduleStart();
    };
    mapReadyNotifier.addListener(_deferredWebBootstrapListener!);
  }

  Future<void> _runDeferredWebBootstrap() async {
    StartupTrace.log('BOOT', 'web post-splash bootstrap start');
    _startDeferredFirebaseDependentServices();
    await _initializePremiumService(true);
    StartupTrace.log('BOOT', 'web post-splash bootstrap complete');
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
  void dispose() {
    final listener = _deferredWebBootstrapListener;
    if (listener != null) {
      mapReadyNotifier.removeListener(listener);
      _deferredWebBootstrapListener = null;
    }
    super.dispose();
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
                // ── Seules les routes critiques startup restent ici ──
                '/splash': (_) => const SplashWrapperPage(),
                '/': (_) => kIsWeb
                    ? const DefaultMapPage()
                    : _DeferredLoader(
                        load: _home3d.loadLibrary,
                        build: () => _home3d.HomeMapPage3D(),
                      ),
                '/map-web': (_) => const DefaultMapPage(),
              },
              onGenerateRoute: _onGenerateRoute,
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

// ─────────────────────────────────────────────────────────────────────────────
// onGenerateRoute — toutes les routes secondaires, chargées à la demande.
// ─────────────────────────────────────────────────────────────────────────────
Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  final name = settings.name;
  final args = settings.arguments;
  Widget? page;

  switch (name) {
    // ── Maps ──
    case '/mapbox-web':
    case '/map-3d':
      page = _DeferredLoader(load: _mapboxWeb.loadLibrary, build: () => _mapboxWeb.MapboxWebMapPage());
      break;

    // ── Account ──
    case '/account-ui':
      page = _DeferredLoader(load: _accountUi.loadLibrary, build: () => _accountUi.AccountUiPage());
      break;
    case '/account':
    case '/account-admin':
      page = _DeferredLoader(load: _account.loadLibrary, build: () => _account.AccountAndAdminPage());
      break;
    case '/login':
      page = _DeferredLoader(load: _login.loadLibrary, build: () => _login.LoginPage());
      break;

    // ── Shop / Boutique ──
    case '/shop-ui':
    case '/boutique':
      page = _DeferredLoader(load: _storexShop.loadLibrary, build: () => _storexShop.StorexShopPage(shopId: 'global', groupId: 'MASLIVE'));
      break;
    case '/shop':
      final groupId = args is String ? args : 'groupe_demo';
      page = _DeferredLoader(load: _grpShop.loadLibrary, build: () => _grpShop.GroupShopPage(groupId: groupId));
      break;
    case '/boutique-photo':
      page = _DeferredLoader(load: _photoShop.loadLibrary, build: () => _photoShop.MediaPhotoShopPage());
      break;

    // ── Storex (reviews / payment / tracker) ──
    case StorexRoutes.paymentComplete:
      page = _DeferredLoader(load: _storexReviews.loadLibrary, build: () {
        if (args is PaymentCompleteArgs) {
          return _storexReviews.PaymentCompletePage(orderCode: args.orderCode, continueToRoute: args.continueToRoute);
        }
        return const _RouteArgsErrorPage(routeName: '/storex/paymentComplete');
      });
      break;
    case StorexRoutes.reviews:
      page = _DeferredLoader(load: _storexReviews.loadLibrary, build: () {
        if (args is ReviewsArgs) {
          return _storexReviews.ReviewsPage(productId: args.productId, productTitle: args.productTitle);
        }
        return const _RouteArgsErrorPage(routeName: '/storex/reviews');
      });
      break;
    case StorexRoutes.addReview:
      page = _DeferredLoader(load: _storexReviews.loadLibrary, build: () {
        if (args is AddReviewArgs) {
          return _storexReviews.AddReviewPage(productId: args.productId, productTitle: args.productTitle);
        }
        return const _RouteArgsErrorPage(routeName: '/storex/addReview');
      });
      break;
    case StorexRoutes.orderTracker:
      page = _DeferredLoader(load: _storexReviews.loadLibrary, build: () {
        if (args is OrderTrackerArgs) {
          return _storexReviews.OrderTrackerPage(orderId: args.orderId);
        }
        return const _RouteArgsErrorPage(routeName: '/storex/orderTracker');
      });
      break;

    // ── App / Group ──
    case '/app':
      final m = args is Map ? args : null;
      final groupId = m?['groupId'] as String? ?? 'groupe_demo';
      page = _DeferredLoader(load: _appShell.loadLibrary, build: () => _appShell.AppShell(groupId: groupId));
      break;
    case '/group':
    case '/group-ui':
      page = _DeferredLoader(load: _grpProfile.loadLibrary, build: () => _grpProfile.GroupProfilePage(groupId: 'groupe_demo'));
      break;
    case '/group-member':
      final m = args is Map ? args : null;
      final groupId = m?['groupId'] as String?;
      page = _DeferredLoader(load: _grpMember.loadLibrary, build: () => _grpMember.GroupMemberPage(groupId: groupId));
      break;
    case '/group-admin':
      page = _DeferredLoader(load: _grpAdmin.loadLibrary, build: () => _grpAdmin.AdminGroupDashboardPage());
      break;
    case '/group-tracker':
      page = _DeferredLoader(load: _grpTracker.loadLibrary, build: () => _grpTracker.TrackerGroupProfilePage());
      break;
    case '/group-live':
      final m = args is Map ? args : null;
      final adminGroupId = (m?['adminGroupId'] as String?) ?? '000000';
      page = _DeferredLoader(load: _grpLive.loadLibrary, build: () => _grpLive.GroupMapLivePage(adminGroupId: adminGroupId));
      break;
    case '/group-history':
      final m = args is Map ? args : null;
      final adminGroupId = (m?['adminGroupId'] as String?) ?? '000000';
      final uid = m?['uid'] as String?;
      page = _DeferredLoader(load: _grpHistory.loadLibrary, build: () => _grpHistory.GroupTrackHistoryPage(adminGroupId: adminGroupId, uid: uid));
      break;
    case '/group-export':
      final m = args is Map ? args : null;
      final adminGroupId = (m?['adminGroupId'] as String?) ?? '000000';
      final uid = m?['uid'] as String?;
      page = _DeferredLoader(load: _grpExport.loadLibrary, build: () => _grpExport.GroupExportPage(adminGroupId: adminGroupId, uid: uid));
      break;

    // ── Orders / Seller ──
    case '/orders':
      page = _DeferredLoader(load: _orders.loadLibrary, build: () => _orders.OrdersPage());
      break;
    case '/seller-inbox':
      page = _DeferredLoader(load: _sellerInbox.loadLibrary, build: () => _sellerInbox.SellerInboxPage());
      break;
    case '/seller-order':
      final orderId = args is String ? args : null;
      if (orderId == null || orderId.trim().isEmpty) {
        page = const _RouteArgsErrorPage(routeName: '/seller-order');
      } else {
        page = _DeferredLoader(load: _sellerOrder.loadLibrary, build: () => _sellerOrder.SellerOrderDetailPage(orderId: orderId));
      }
      break;

    // ── Circuits ──
    case '/circuit-import-export':
      page = _DeferredLoader(load: _circuitIO.loadLibrary, build: () => _circuitIO.CircuitImportExportPage());
      break;
    case '/circuit-calculs':
      page = _DeferredLoader(load: _circuitCalc.loadLibrary, build: () => _circuitCalc.CircuitCalculsValidationPage());
      break;
    case '/circuit-save':
      page = _DeferredLoader(load: _circuitSave.loadLibrary, build: () => _circuitSave.CircuitSavePage());
      break;
    case '/circuit-draw':
      page = _DeferredLoader(load: _circuitDraw.loadLibrary, build: () => _circuitDraw.CircuitDrawPage());
      break;

    // ── Tracking / Search / Favorites ──
    case '/tracking':
      page = _DeferredLoader(load: _tracking.loadLibrary, build: () => _tracking.TrackingLivePage());
      break;
    case '/search':
      page = _DeferredLoader(load: _search.loadLibrary, build: () => _search.SearchPage());
      break;
    case '/favorites':
      page = _DeferredLoader(load: _favorites.loadLibrary, build: () => _favorites.FavoritesPage());
      break;

    // ── Cart / Paywall / Purchase ──
    case '/cart':
    case '/media-marketplace/cart':
      page = _DeferredLoader(load: _cart.loadLibrary, build: () => _cart.UnifiedCartPage());
      break;
    case '/paywall':
      page = _DeferredLoader(load: _paywall.loadLibrary, build: () => _paywall.PaywallPage());
      break;
    case '/pending-products':
      page = _DeferredLoader(load: _pendingProd.loadLibrary, build: () => _pendingProd.PendingProductsPage());
      break;
    case '/purchase-history':
      page = _DeferredLoader(load: _purchaseHist.loadLibrary, build: () => _purchaseHist.PurchaseHistoryPage());
      break;

    // ── Business ──
    case '/business':
      page = _DeferredLoader(load: _bizAccount.loadLibrary, build: () => _bizAccount.BusinessAccountPage());
      break;
    case '/business-request':
      page = _DeferredLoader(load: _bizRequest.loadLibrary, build: () => _bizRequest.BusinessRequestPage());
      break;

    // ── Commerce ──
    case '/commerce/create-product':
      page = _DeferredLoader(load: _createProduct.loadLibrary, build: () => _createProduct.CreateProductPage());
      break;
    case '/commerce/create-media':
      page = _DeferredLoader(load: _createMedia.loadLibrary, build: () => _createMedia.CreateMediaPage());
      break;
    case '/commerce/my-submissions':
      page = _DeferredLoader(load: _mySubmissions.loadLibrary, build: () => _mySubmissions.MySubmissionsPage());
      break;

    // ── Admin ──
    case '/admin':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admMain.loadLibrary, build: () => _admMain.AdminMainDashboard()));
      break;
    case '/admin/circuits':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admCircuits.loadLibrary, build: () => _admCircuits.AdminCircuitsPage()));
      break;
    case '/admin/track-editor':
      page = AdminRouteGuard(child: _DeferredLoader(load: _circuitEditor.loadLibrary, build: () => _circuitEditor.CircuitEditorWorkflowPage()));
      break;
    case '/admin/map-library':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admMapLib.loadLibrary, build: () => _admMapLib.MapProjectsLibraryPage()));
      break;
    case '/admin/mapmarket':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admMapmarket.loadLibrary, build: () => _admMapmarket.MapMarketProjectsPage()));
      break;
    case '/admin/mapmarket/wizard':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admMapWiz.loadLibrary, build: () => _admMapWiz.MapProjectWizardEntryPage()));
      break;
    case '/admin/marketmap-debug':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admMarketDebug.loadLibrary, build: () => _admMarketDebug.MarketMapDebugPage()));
      break;
    case '/admin/circuit-wizard':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admCircuitWiz.loadLibrary, build: () => _admCircuitWiz.CircuitWizardEntryPage()));
      break;
    case '/admin/mapbox-style-studio':
      page = AdminRouteGuard(child: _DeferredLoader(load: _mapStyleStudio.loadLibrary, build: () => _mapStyleStudio.MapboxStyleStudioPage()));
      break;
    case '/admin/route-style-pro':
      page = AdminRouteGuard(child: _DeferredLoader(load: _routeStylePro.loadLibrary, build: () {
        if (args is RouteStyleProArgs) {
          return _routeStylePro.RouteStyleWizardProPage(
            projectId: args.projectId,
            circuitId: args.circuitId,
            initialRoute: args.initialRoute,
            initialStyleUrl: args.initialStyleUrl,
          );
        }
        return _routeStylePro.RouteStyleWizardProPage();
      }));
      break;
    case '/admin/superadmin':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admSuper.loadLibrary, build: () => _admSuper.SuperAdminSpace()));
      break;
    case '/admin/categories':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admCategories.loadLibrary, build: () => _admCategories.CategoryManagementPage()));
      break;
    case '/admin/roles':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admRoles.loadLibrary, build: () => _admRoles.RoleManagementPage()));
      break;
    case '/admin/business-requests':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admBizReq.loadLibrary, build: () => _admBizReq.BusinessRequestsPage()));
      break;
    case '/admin/commerce':
      page = AdminRouteGuard(child: _DeferredLoader(load: _commerce.loadLibrary, build: () => _commerce.ProductManagementPage(shopId: 'global')));
      break;
    case '/admin/moderation':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admModeration.loadLibrary, build: () => _admModeration.AdminModerationPage()));
      break;
    case '/admin/commerce-analytics':
      page = AdminRouteGuard(child: _DeferredLoader(load: _admComAnalytics.loadLibrary, build: () => _admComAnalytics.CommerceAnalyticsPage()));
      break;
    case '/admin/media-marketplace/moderation':
      page = AdminRouteGuard(child: _DeferredLoader(load: _mediaMarket.loadLibrary, build: () => _mediaMarket.AdminModerationQueuePage()));
      break;
    case '/map-admin':
      page = AdminRouteGuard(child: _DeferredLoader(load: _mapAdmin.loadLibrary, build: () => _mapAdmin.MapAdminEditorPage()));
      break;

    // ── Media Marketplace ──
    case '/media-marketplace':
      page = _DeferredLoader(load: _mediaMarket.loadLibrary, build: () {
        int initialTabIndex = 0;
        if (args is Map) {
          final initialTab = args['initialTab'];
          if (initialTab is int) {
            initialTabIndex = initialTab;
          } else if (initialTab is String) {
            switch (initialTab) {
              case 'cart': initialTabIndex = 1; break;
              case 'downloads': initialTabIndex = 2; break;
              case 'photographer': initialTabIndex = 3; break;
              default: initialTabIndex = 0;
            }
          }
          return _mediaMarket.MediaMarketplaceEntryPage(
            countryId: args['countryId'] as String?,
            countryName: args['countryName'] as String?,
            eventId: args['eventId'] as String?,
            eventName: args['eventName'] as String?,
            circuitId: args['circuitId'] as String?,
            circuitName: args['circuitName'] as String?,
            photographerId: args['photographerId'] as String?,
            ownerUid: args['ownerUid'] as String?,
            initialTabIndex: initialTabIndex,
          );
        }
        return _mediaMarket.MediaMarketplaceEntryPage();
      });
      break;
    case '/media-marketplace/success':
      page = _MediaMarketplaceCheckoutReturnPage(succeeded: true, orderId: _routeQueryParam('orderId'));
      break;
    case '/media-marketplace/cancel':
      page = _MediaMarketplaceCheckoutReturnPage(succeeded: false, orderId: _routeQueryParam('orderId'));
      break;
    case '/media-marketplace/downloads':
      page = _DeferredLoader(load: _mediaMarket.loadLibrary, build: () => _mediaMarket.MediaDownloadsPage());
      break;
    case '/media-marketplace/photographer':
      page = _DeferredLoader(load: _mediaMarket.loadLibrary, build: () => _mediaMarket.PhotographerDashboardPage());
      break;
    case '/media-marketplace/subscription':
      page = _DeferredLoader(load: _mediaMarket.loadLibrary, build: () => _mediaMarket.PhotographerSubscriptionPage());
      break;

    // ── Public ──
    case '/public/marketmap':
      page = _DeferredLoader(load: _publicMap.loadLibrary, build: () {
        if (args is Map) {
          final countryId = args['countryId'] as String?;
          final eventId = args['eventId'] as String?;
          if (countryId != null && eventId != null) {
            return _publicMap.MarketMapPublicViewerPage(
              countryId: countryId,
              eventId: eventId,
              initialCircuitId: args['initialCircuitId'] as String?,
              accessToken: args['accessToken'] as String?,
            );
          }
        }
        return const _RouteArgsErrorPage(routeName: '/public/marketmap');
      });
      break;
  }

  if (page == null) return null;
  return MaterialPageRoute<dynamic>(builder: (_) => page!, settings: settings);
}

/// Widget helper pour le chargement différé d'un module (deferred import).
/// Affiche un spinner le temps que le code soit téléchargé, puis construit
/// le widget final via [build].
class _DeferredLoader extends StatelessWidget {
  const _DeferredLoader({required this.load, required Widget Function() build})
      : _buildPage = build;
  final Future<void> Function() load;
  final Widget Function() _buildPage;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && !snap.hasError) {
          return _buildPage();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
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
