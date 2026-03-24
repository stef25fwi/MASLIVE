import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'session/session_controller.dart';
import 'session/session_scope.dart';
import 'services/localization_service.dart' show LocalizationService;
import 'services/language_service.dart';
import 'widgets/localized_app.dart';
import 'pages/splash_wrapper_page.dart';
import 'pages/group_profile_page.dart';
import 'pages/group_shop_page.dart';
import 'pages/role_router_page.dart';
import 'pages/group_member_page.dart';
import 'pages/login_page.dart';
import 'pages/tracking_live_page.dart';
import 'pages/app_shell.dart';
import 'pages/cart/unified_cart_page.dart';
import 'pages/paywall_page.dart';
import 'pages/account_admin_page.dart';
import 'pages/account_page.dart';
import 'pages/orders_page.dart';
import 'pages/map_admin_editor_page.dart';
import 'pages/storex_shop_page.dart';
import 'features/shop/pages/media_photo_shop_page.dart';
import 'pages/shop/storex_reviews_and_success_pages.dart';
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
import 'commerce_module_single_file.dart';
import 'admin/category_management_page.dart';
import 'admin/role_management_page.dart';
import 'admin/admin_circuits_page.dart';
import 'admin/map_projects_library_page.dart';
import 'admin/business_requests_page.dart';
import 'admin/admin_main_dashboard.dart';
import 'admin/mapmarket_projects_page.dart';
import 'admin/map_project_wizard_entry_page.dart';
import 'admin/marketmap_debug_page.dart';
import 'admin/circuit_wizard_entry_page.dart';
import 'services/cart_service.dart';
import 'services/notifications_service.dart';
import 'services/premium_service.dart';
import 'services/mapbox_token_service.dart';
import 'ui/theme/maslive_theme.dart';
import 'ui/widgets/honeycomb_background.dart';
import 'l10n/app_localizations.dart';
import 'pages/circuit_editor_workflow_page.dart';
import 'pages/splash_screen.dart';
import 'pages/seller/seller_inbox_page.dart';
import 'pages/seller/seller_order_detail_page.dart';
import 'pages/commerce/create_product_page.dart';
import 'pages/commerce/create_media_page.dart';
import 'pages/commerce/my_submissions_page.dart';
import 'admin/admin_moderation_page.dart';
import 'admin/commerce_analytics_page.dart';
import 'route_style_pro/ui/route_style_wizard_pro_page.dart';
import 'features/media_marketplace/presentation/pages/media_marketplace_pages.dart';
import 'features/map_style/presentation/pages/mapbox_style_studio_page.dart';
import 'pages/group/admin_group_dashboard_page.dart';
import 'pages/group/tracker_group_profile_page.dart';
import 'pages/group/group_map_live_page.dart';
import 'pages/group/group_track_history_page.dart';
import 'pages/group/group_export_page.dart';
import 'pages/public/marketmap_public_viewer_page.dart';
import 'providers/cart_provider.dart';
import 'widgets/admin_route_guard.dart';

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

  // ✅ Important: ne jamais bloquer avant le premier frame.
  // Sinon l'utilisateur reste coincé sur le splash natif (Android/iOS) ou sur
  // le loader web sans que la splash Flutter n'apparaisse.
  runApp(const _BootstrapRoot());
}

class _BootResult {
  final SessionController session;
  const _BootResult({required this.session});
}

class _BootstrapRoot extends StatefulWidget {
  const _BootstrapRoot();

  @override
  State<_BootstrapRoot> createState() => _BootstrapRootState();
}

class _BootstrapRootState extends State<_BootstrapRoot> {
  late final Future<_BootResult> _boot;
  _BootResult? _fallbackBootResult;

  @override
  void initState() {
    super.initState();
    _boot = _bootstrap();
  }

  Future<_BootResult> _bootstrap() async {
    final session = SessionController();

    try {
      // 1) Firebase: requis pour auth/firestore. On timeoute pour éviter un blocage infini.
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('❌ Bootstrap: Firebase.initializeApp failed/timeout: $e');
        // On continue quand même pour afficher l'UI (les pages Firebase pourront
        // afficher leurs erreurs au lieu d'un splash natif infini).
      }

      // 2) Stripe (native uniquement): ne doit jamais bloquer le démarrage.
      if (!kIsWeb) {
        const stripePublishableKey = String.fromEnvironment(
          'STRIPE_PUBLISHABLE_KEY',
          defaultValue: '',
        );
        if (stripePublishableKey.isNotEmpty) {
          Stripe.publishableKey = stripePublishableKey;
          try {
            await Stripe.instance
                .applySettings()
                .timeout(const Duration(seconds: 4));
          } catch (e) {
            debugPrint('⚠️ Bootstrap: Stripe applySettings skipped: $e');
          }
        } else {
          debugPrint('⚠️ Bootstrap: STRIPE_PUBLISHABLE_KEY missing, Stripe skipped');
        }
      }

      // 3) Mapbox token warmup: SharedPreferences (rapide) mais on timeoute par sûreté.
      try {
        await MapboxTokenService.warmUp().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('⚠️ Bootstrap: MapboxTokenService.warmUp skipped: $e');
      }

      // 4) LanguageService: doit exister avant build() (Get.find). Init best-effort.
      try {
        await Get.putAsync(() => LanguageService().init())
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('⚠️ Bootstrap: LanguageService init fallback: $e');
        if (!Get.isRegistered<LanguageService>()) {
          Get.put(LanguageService());
        }
      }

      // 5) PremiumService: jamais bloquant (plugins réseau). On lance en arrière-plan.
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
      } else {
        unawaited(
          PremiumService.instance
              .init(
                revenueCatApiKey: revenueCatApiKey,
                entitlementId: 'premium',
              )
              .timeout(const Duration(seconds: 8))
              .catchError((e) {
            debugPrint('⚠️ Bootstrap: PremiumService init skipped: $e');
          }),
        );
      }
    } catch (e, st) {
      debugPrint('❌ Bootstrap: unexpected failure: $e');
      debugPrint('$st');
    }

    try {
      session.start();
    } catch (e) {
      debugPrint('⚠️ Bootstrap: SessionController.start skipped: $e');
    }
    try {
      CartService.instance.start();
    } catch (e) {
      debugPrint('⚠️ Bootstrap: CartService.start skipped: $e');
    }
    try {
      NotificationsService.instance.start(navigatorKey: _rootNavigatorKey);
    } catch (e) {
      debugPrint('⚠️ Bootstrap: NotificationsService.start skipped: $e');
    }

    return _BootResult(session: session);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootResult>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _fallbackBootResult ??= _BootResult(session: SessionController()..start());
          debugPrint('❌ Bootstrap: FutureBuilder received error: ${snapshot.error}');
          return MasLiveApp(session: _fallbackBootResult!.session);
        }
        final boot = snapshot.data;
        if (boot == null) {
          // UI ultra-minimale pendant init, pour enlever le splash natif le plus vite possible.
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SplashScreen(),
          );
        }
        return MasLiveApp(session: boot.session);
      },
    );
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
              '/': (_) => const DefaultMapPage(),
              // '/map-legacy': (_) => const HomeMapPageV3(), // 🔄 Moved to legacy
              // Alias legacy: conserve l'URL mais évite 2 "Home carte" différents.
              '/map-web': (_) => const DefaultMapPage(),

              // Debug Web Mapbox (GL JS). Gardé pour l'admin.
              '/mapbox-web': (_) => const MapboxWebMapPage(),

              // Alias historique (nom trompeur): redirige vers la page debug Mapbox web.
              '/map-3d': (_) => const MapboxWebMapPage(),
              // '/mapbox-google-light': (_) => const GoogleLightMapPage(), // Moved to legacy
              '/account-ui': (_) => const AccountUiPage(),
              '/shop-ui': (_) =>
                  const StorexShopPage(shopId: "global", groupId: "MASLIVE"),
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
                  const StorexShopPage(shopId: "global", groupId: "MASLIVE"),
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
                  return const _RouteArgsErrorPage(routeName: '/seller-order');
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
                // Sans args: fallback local + itinéraire de démo.
                return const AdminRouteGuard(child: RouteStyleWizardProPage());
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
              '/circuit-import-export': (_) => const CircuitImportExportPage(),
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
              '/media-marketplace/downloads': (_) =>
                  const MediaDownloadsPage(),
              '/media-marketplace/photographer': (_) =>
                  const PhotographerDashboardPage(),
              '/media-marketplace/subscription': (_) =>
                  const PhotographerSubscriptionPage(),
              '/admin/media-marketplace/moderation': (_) =>
                  const AdminRouteGuard(child: AdminModerationQueuePage()),

              // Public (mobile): viewer MarketMap
              '/public/marketmap': (ctx) {
                final args = ModalRoute.of(ctx)?.settings.arguments;
                if (args is Map) {
                  final countryId = args['countryId'] as String?;
                  final eventId = args['eventId'] as String?;
                  final initialCircuitId = args['initialCircuitId'] as String?;
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

              // Groupe (Admin/Tracker)
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
