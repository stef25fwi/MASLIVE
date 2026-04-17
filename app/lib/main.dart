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
import 'admin/admin_main_dashboard.dart' deferred as adm_main;
import 'admin/admin_circuits_page.dart' deferred as adm_circuits;
import 'admin/admin_moderation_page.dart' deferred as adm_moderation;
import 'admin/business_requests_page.dart' deferred as adm_biz_req;
import 'admin/category_management_page.dart' deferred as adm_categories;
import 'admin/circuit_wizard_entry_page.dart' deferred as adm_circuit_wiz;
import 'admin/commerce_analytics_page.dart' deferred as adm_com_analytics;
import 'admin/map_projects_library_page.dart' deferred as adm_map_lib;
import 'admin/map_project_wizard_entry_page.dart' deferred as adm_map_wiz;
import 'admin/marketmap_debug_page.dart' deferred as adm_market_debug;
import 'admin/mapmarket_projects_page.dart' deferred as adm_mapmarket;
import 'admin/role_management_page.dart' deferred as adm_roles;
import 'admin/super_admin_space.dart' deferred as adm_super;
import 'commerce_module_single_file.dart' deferred as commerce;
import 'features/map_style/presentation/pages/map_color_tuner_page.dart' deferred as map_color_tuner;
import 'features/map_style/presentation/pages/mapbox_style_studio_page.dart' deferred as map_style_studio;
import 'features/media_marketplace/presentation/pages/media_marketplace_pages.dart' deferred as media_market;
import 'features/shop/pages/media_photo_shop_page.dart' deferred as photo_shop;
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
// ── Eager: léger, args/routes constants ──
import 'pages/shop/storex_route_args.dart';
import 'route_style_pro/ui/route_style_pro_args.dart';
// ── Eager: pages critiques au démarrage ──
import 'pages/default_map_page.dart';
import 'pages/splash_wrapper_page.dart';
// ── Deferred: toutes les autres pages (chargées à la demande) ──
import 'pages/account_admin_page.dart' deferred as account;
import 'pages/app_shell.dart' deferred as app_shell;
import 'pages/business_account_page.dart' deferred as biz_account;
import 'pages/business_request_page.dart' deferred as biz_request;
import 'pages/cart/unified_cart_page.dart' deferred as cart;
import 'pages/circuit_calculs_validation_page.dart' deferred as circuit_calc;
import 'pages/circuit_draw_page.dart' deferred as circuit_draw;
import 'pages/circuit_editor_workflow_page.dart' deferred as circuit_editor;
import 'pages/circuit_import_export_page.dart' deferred as circuit_io;
import 'pages/circuit_save_page.dart' deferred as circuit_save;
import 'pages/favorites_page.dart' deferred as favorites;
import 'pages/group/admin_group_dashboard_page.dart' deferred as grp_admin;
import 'pages/group/group_export_page.dart' deferred as grp_export;
import 'pages/group/group_map_live_page.dart' deferred as grp_live;
import 'pages/group/group_track_history_page.dart' deferred as grp_history;
import 'pages/group/tracker_group_profile_page.dart' deferred as grp_tracker;
import 'pages/group_member_page.dart' deferred as grp_member;
import 'pages/group_profile_page.dart' deferred as grp_profile;
import 'pages/group_shop_page.dart' deferred as grp_shop;
import 'pages/home_map_page_3d.dart' deferred as home3d;
import 'pages/map_admin_editor_page.dart' deferred as map_admin;
import 'pages/mapbox_web_map_page.dart' deferred as mapbox_web;
import 'pages/orders_page.dart' deferred as orders;
import 'pages/paywall_page.dart' deferred as paywall;
import 'pages/pending_products_page.dart' deferred as pending_prod;
import 'pages/public/marketmap_public_viewer_page.dart' deferred as public_map;
import 'pages/purchase_history_page.dart' deferred as purchase_hist;
import 'pages/seller/seller_inbox_page.dart' deferred as seller_inbox;
import 'pages/seller/seller_order_detail_page.dart' deferred as seller_order;
import 'pages/shop/storex_reviews_and_success_pages.dart' deferred as storex_reviews;
import 'pages/tracking_live_page.dart' deferred as tracking;
import 'pages/user_facing_shell_page.dart' deferred as user_shell;
import 'pages/commerce/create_media_page.dart' deferred as create_media;
import 'pages/commerce/create_product_page.dart' deferred as create_product;
import 'pages/commerce/my_submissions_page.dart' deferred as my_submissions;
import 'route_style_pro/ui/route_style_wizard_pro_page.dart' deferred as route_style_pro;
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
  bool _didWarmDeferredNavigationModules = false;

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
      _scheduleDeferredNavigationWarmup();
      return;
    }

    StartupTrace.log('BOOT', 'background bootstrap complete');
    _scheduleDeferredNavigationWarmup();
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
    _scheduleDeferredNavigationWarmup();
  }

  void _scheduleDeferredNavigationWarmup() {
    if (_didWarmDeferredNavigationModules) return;
    _didWarmDeferredNavigationModules = true;

    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      unawaited(_warmDeferredNavigationModules());
    });
  }

  Future<void> _warmDeferredNavigationModules() async {
    StartupTrace.log('BOOT', 'deferred navigation warmup start');
    final warmups = <Future<void> Function()>[
      user_shell.loadLibrary,
      account.loadLibrary,
      adm_main.loadLibrary,
      adm_circuit_wiz.loadLibrary,
      map_color_tuner.loadLibrary,
      route_style_pro.loadLibrary,
    ];

    for (final warmup in warmups) {
      try {
        await warmup();
      } catch (error) {
        StartupTrace.log('BOOT', 'deferred navigation warmup failed: $error');
      }
    }

    StartupTrace.log('BOOT', 'deferred navigation warmup complete');
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
      await MapboxTokenService.warmUp().timeout(const Duration(seconds: 10));
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
                        load: home3d.loadLibrary,
                        build: () => home3d.HomeMapPage3D(),
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
      page = _DeferredLoader(load: mapbox_web.loadLibrary, build: () => mapbox_web.MapboxWebMapPage());
      break;

    // ── Account ──
    case '/user-shell':
      page = _DeferredLoader(
        load: user_shell.loadLibrary,
        build: () => user_shell.UserFacingShellPage(initialTab: args),
      );
      break;
    case '/account-ui':
      page = _DeferredLoader(
        load: user_shell.loadLibrary,
        build: () => user_shell.UserFacingShellPage(
          initialTab: <String, dynamic>{'tab': 'profile'},
        ),
      );
      break;
    case '/account':
    case '/account-admin':
      page = _DeferredLoader(load: account.loadLibrary, build: () => account.AccountAndAdminPage());
      break;
    case '/login':
      page = _DeferredLoader(
        load: user_shell.loadLibrary,
        build: () => user_shell.UserFacingShellPage(
          initialTab: <String, dynamic>{'tab': 'profile'},
        ),
      );
      break;

    // ── Shop / Boutique ──
    case '/shop-ui':
    case '/boutique':
      page = _DeferredLoader(
        load: user_shell.loadLibrary,
        build: () => user_shell.UserFacingShellPage(
          initialTab: <String, dynamic>{'tab': 'boutique'},
        ),
      );
      break;
    case '/shop':
      final groupId = args is String ? args : 'groupe_demo';
      page = _DeferredLoader(load: grp_shop.loadLibrary, build: () => grp_shop.GroupShopPage(groupId: groupId));
      break;
    case '/boutique-photo':
      page = _DeferredLoader(load: photo_shop.loadLibrary, build: () => photo_shop.MediaPhotoShopPage());
      break;

    // ── Storex (reviews / payment / tracker) ──
    case StorexRoutes.paymentComplete:
      page = _DeferredLoader(load: storex_reviews.loadLibrary, build: () {
        if (args is PaymentCompleteArgs) {
          return storex_reviews.PaymentCompletePage(orderCode: args.orderCode, continueToRoute: args.continueToRoute);
        }
        return const _RouteArgsErrorPage(routeName: '/storex/paymentComplete');
      });
      break;
    case StorexRoutes.reviews:
      page = _DeferredLoader(load: storex_reviews.loadLibrary, build: () {
        if (args is ReviewsArgs) {
          return storex_reviews.ReviewsPage(productId: args.productId, productTitle: args.productTitle);
        }
        return const _RouteArgsErrorPage(routeName: '/storex/reviews');
      });
      break;
    case StorexRoutes.addReview:
      page = _DeferredLoader(load: storex_reviews.loadLibrary, build: () {
        if (args is AddReviewArgs) {
          return storex_reviews.AddReviewPage(productId: args.productId, productTitle: args.productTitle);
        }
        return const _RouteArgsErrorPage(routeName: '/storex/addReview');
      });
      break;
    case StorexRoutes.orderTracker:
      page = _DeferredLoader(load: storex_reviews.loadLibrary, build: () {
        if (args is OrderTrackerArgs) {
          return storex_reviews.OrderTrackerPage(orderId: args.orderId);
        }
        return const _RouteArgsErrorPage(routeName: '/storex/orderTracker');
      });
      break;

    // ── App / Group ──
    case '/app':
      final m = args is Map ? args : null;
      final groupId = m?['groupId'] as String? ?? 'groupe_demo';
      page = _DeferredLoader(load: app_shell.loadLibrary, build: () => app_shell.AppShell(groupId: groupId));
      break;
    case '/group':
    case '/group-ui':
      page = _DeferredLoader(load: grp_profile.loadLibrary, build: () => grp_profile.GroupProfilePage(groupId: 'groupe_demo'));
      break;
    case '/group-member':
      final m = args is Map ? args : null;
      final groupId = m?['groupId'] as String?;
      page = _DeferredLoader(load: grp_member.loadLibrary, build: () => grp_member.GroupMemberPage(groupId: groupId));
      break;
    case '/group-admin':
      page = _DeferredLoader(load: grp_admin.loadLibrary, build: () => grp_admin.AdminGroupDashboardPage());
      break;
    case '/group-tracker':
      page = _DeferredLoader(load: grp_tracker.loadLibrary, build: () => grp_tracker.TrackerGroupProfilePage());
      break;
    case '/group-live':
      final m = args is Map ? args : null;
      final adminGroupId = (m?['adminGroupId'] as String?) ?? '000000';
      page = _DeferredLoader(load: grp_live.loadLibrary, build: () => grp_live.GroupMapLivePage(adminGroupId: adminGroupId));
      break;
    case '/group-history':
      final m = args is Map ? args : null;
      final adminGroupId = (m?['adminGroupId'] as String?) ?? '000000';
      final uid = m?['uid'] as String?;
      page = _DeferredLoader(load: grp_history.loadLibrary, build: () => grp_history.GroupTrackHistoryPage(adminGroupId: adminGroupId, uid: uid));
      break;
    case '/group-export':
      final m = args is Map ? args : null;
      final adminGroupId = (m?['adminGroupId'] as String?) ?? '000000';
      final uid = m?['uid'] as String?;
      page = _DeferredLoader(load: grp_export.loadLibrary, build: () => grp_export.GroupExportPage(adminGroupId: adminGroupId, uid: uid));
      break;

    // ── Orders / Seller ──
    case '/orders':
      page = _DeferredLoader(load: orders.loadLibrary, build: () => orders.OrdersPage());
      break;
    case '/seller-inbox':
      page = _DeferredLoader(load: seller_inbox.loadLibrary, build: () => seller_inbox.SellerInboxPage());
      break;
    case '/seller-order':
      final orderId = args is String ? args : null;
      if (orderId == null || orderId.trim().isEmpty) {
        page = const _RouteArgsErrorPage(routeName: '/seller-order');
      } else {
        page = _DeferredLoader(load: seller_order.loadLibrary, build: () => seller_order.SellerOrderDetailPage(orderId: orderId));
      }
      break;

    // ── Circuits ──
    case '/circuit-import-export':
      page = _DeferredLoader(load: circuit_io.loadLibrary, build: () => circuit_io.CircuitImportExportPage());
      break;
    case '/circuit-calculs':
      page = _DeferredLoader(load: circuit_calc.loadLibrary, build: () => circuit_calc.CircuitCalculsValidationPage());
      break;
    case '/circuit-save':
      page = _DeferredLoader(load: circuit_save.loadLibrary, build: () => circuit_save.CircuitSavePage());
      break;
    case '/circuit-draw':
      page = _DeferredLoader(load: circuit_draw.loadLibrary, build: () => circuit_draw.CircuitDrawPage());
      break;

    // ── Tracking / Search / Favorites ──
    case '/tracking':
      page = _DeferredLoader(load: tracking.loadLibrary, build: () => tracking.TrackingLivePage());
      break;
    case '/search':
      page = _DeferredLoader(
        load: user_shell.loadLibrary,
        build: () => user_shell.UserFacingShellPage(
          initialTab: <String, dynamic>{'tab': 'explorer'},
        ),
      );
      break;
    case '/favorites':
      page = _DeferredLoader(load: favorites.loadLibrary, build: () => favorites.FavoritesPage());
      break;

    // ── Cart / Paywall / Purchase ──
    case '/cart':
    case '/media-marketplace/cart':
      page = _DeferredLoader(load: cart.loadLibrary, build: () => cart.UnifiedCartPage());
      break;
    case '/paywall':
      page = _DeferredLoader(load: paywall.loadLibrary, build: () => paywall.PaywallPage());
      break;
    case '/pending-products':
      page = _DeferredLoader(load: pending_prod.loadLibrary, build: () => pending_prod.PendingProductsPage());
      break;
    case '/purchase-history':
      page = _DeferredLoader(load: purchase_hist.loadLibrary, build: () => purchase_hist.PurchaseHistoryPage());
      break;

    // ── Business ──
    case '/business':
      page = _DeferredLoader(load: biz_account.loadLibrary, build: () => biz_account.BusinessAccountPage());
      break;
    case '/business-request':
      page = _DeferredLoader(load: biz_request.loadLibrary, build: () => biz_request.BusinessRequestPage());
      break;

    // ── Commerce ──
    case '/commerce/create-product':
      page = _DeferredLoader(load: create_product.loadLibrary, build: () => create_product.CreateProductPage());
      break;
    case '/commerce/create-media':
      page = _DeferredLoader(load: create_media.loadLibrary, build: () => create_media.CreateMediaPage());
      break;
    case '/commerce/my-submissions':
      page = _DeferredLoader(load: my_submissions.loadLibrary, build: () => my_submissions.MySubmissionsPage());
      break;

    // ── Admin ──
    case '/admin':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_main.loadLibrary, build: () => adm_main.AdminMainDashboard()));
      break;
    case '/admin/circuits':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_circuits.loadLibrary, build: () => adm_circuits.AdminCircuitsPage()));
      break;
    case '/admin/track-editor':
      page = AdminRouteGuard(child: _DeferredLoader(load: circuit_editor.loadLibrary, build: () => circuit_editor.CircuitEditorWorkflowPage()));
      break;
    case '/admin/map-library':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_map_lib.loadLibrary, build: () => adm_map_lib.MapProjectsLibraryPage()));
      break;
    case '/admin/mapmarket':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_mapmarket.loadLibrary, build: () => adm_mapmarket.MapMarketProjectsPage()));
      break;
    case '/admin/mapmarket/wizard':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_map_wiz.loadLibrary, build: () => adm_map_wiz.MapProjectWizardEntryPage()));
      break;
    case '/admin/marketmap-debug':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_market_debug.loadLibrary, build: () => adm_market_debug.MarketMapDebugPage()));
      break;
    case '/admin/circuit-wizard':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_circuit_wiz.loadLibrary, build: () => adm_circuit_wiz.CircuitWizardEntryPage()));
      break;
    case '/admin/mapbox-style-studio':
      page = AdminRouteGuard(child: _DeferredLoader(load: map_style_studio.loadLibrary, build: () => map_style_studio.MapboxStyleStudioPage()));
      break;
    case '/admin/map-color-tuner':
      page = AdminRouteGuard(child: _DeferredLoader(load: map_color_tuner.loadLibrary, build: () => map_color_tuner.MapColorTunerPage()));
      break;
    case '/admin/route-style-pro':
      page = AdminRouteGuard(child: _DeferredLoader(load: route_style_pro.loadLibrary, build: () {
        if (args is RouteStyleProArgs) {
          return route_style_pro.RouteStyleWizardProPage(
            projectId: args.projectId,
            circuitId: args.circuitId,
            initialRoute: args.initialRoute,
            initialStyleUrl: args.initialStyleUrl,
          );
        }
        return route_style_pro.RouteStyleWizardProPage();
      }));
      break;
    case '/admin/superadmin':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_super.loadLibrary, build: () => adm_super.SuperAdminSpace()));
      break;
    case '/admin/categories':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_categories.loadLibrary, build: () => adm_categories.CategoryManagementPage()));
      break;
    case '/admin/roles':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_roles.loadLibrary, build: () => adm_roles.RoleManagementPage()));
      break;
    case '/admin/business-requests':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_biz_req.loadLibrary, build: () => adm_biz_req.BusinessRequestsPage()));
      break;
    case '/admin/commerce':
      page = AdminRouteGuard(child: _DeferredLoader(load: commerce.loadLibrary, build: () => commerce.ProductManagementPage(shopId: 'global')));
      break;
    case '/admin/moderation':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_moderation.loadLibrary, build: () => adm_moderation.AdminModerationPage()));
      break;
    case '/admin/commerce-analytics':
      page = AdminRouteGuard(child: _DeferredLoader(load: adm_com_analytics.loadLibrary, build: () => adm_com_analytics.CommerceAnalyticsPage()));
      break;
    case '/admin/media-marketplace/moderation':
      page = AdminRouteGuard(child: _DeferredLoader(load: media_market.loadLibrary, build: () => media_market.AdminModerationQueuePage()));
      break;
    case '/map-admin':
      page = AdminRouteGuard(child: _DeferredLoader(load: map_admin.loadLibrary, build: () => map_admin.MapAdminEditorPage()));
      break;

    // ── Media Marketplace ──
    case '/media-marketplace':
      final mediaInitialTab = args is Map
          ? <String, dynamic>{
              ...args.cast<Object?, Object?>().map(
                (key, value) => MapEntry(key.toString(), value),
              ),
              'tab': 'media',
            }
          : <String, dynamic>{'tab': 'media'};
      page = _DeferredLoader(
        load: user_shell.loadLibrary,
        build: () => user_shell.UserFacingShellPage(
          initialTab: mediaInitialTab,
        ),
      );
      break;
    case '/media-marketplace/success':
      page = _MediaMarketplaceCheckoutReturnPage(succeeded: true, orderId: _routeQueryParam('orderId'));
      break;
    case '/media-marketplace/cancel':
      page = _MediaMarketplaceCheckoutReturnPage(succeeded: false, orderId: _routeQueryParam('orderId'));
      break;
    case '/media-marketplace/downloads':
      page = _DeferredLoader(load: media_market.loadLibrary, build: () => media_market.MediaDownloadsPage());
      break;
    case '/media-marketplace/photographer':
      page = _DeferredLoader(load: media_market.loadLibrary, build: () => media_market.PhotographerDashboardPage());
      break;
    case '/media-marketplace/subscription':
      page = _DeferredLoader(load: media_market.loadLibrary, build: () => media_market.PhotographerSubscriptionPage());
      break;

    // ── Public ──
    case '/public/marketmap':
      page = _DeferredLoader(load: public_map.loadLibrary, build: () {
        if (args is Map) {
          final countryId = args['countryId'] as String?;
          final eventId = args['eventId'] as String?;
          if (countryId != null && eventId != null) {
            return public_map.MarketMapPublicViewerPage(
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
  if (settings.name == '/user-shell') {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => page!,
    );
  }
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
        return const _RouteTransitionPlaceholder();
      },
    );
  }
}

class _RouteTransitionPlaceholder extends StatelessWidget {
  const _RouteTransitionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: Colors.white,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.blur_on_rounded,
                    size: 34,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Ouverture de la page...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Le module est precharge en arriere-plan pour accelerer les transitions suivantes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
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
