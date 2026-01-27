/// EXEMPLE D'INTÉGRATION - MEDIA SHOP V2
///
/// Ce fichier montre comment intégrer la nouvelle page média
/// dans votre application existante.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Import de la nouvelle structure
import 'pages/media_galleries_page_v2.dart';
import 'pages/media_shop_wrapper.dart';

/// ============================================================
/// OPTION 1: Navigation simple depuis un bouton/menu
/// ============================================================

class NavigationExample1 extends StatelessWidget {
  const NavigationExample1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon App')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigation vers la page média shop
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MediaShopWrapper(groupId: 'all'),
              ),
            );
          },
          child: const Text('Voir les galeries photos'),
        ),
      ),
    );
  }
}

/// ============================================================
/// OPTION 2: Onglet dans un BottomNavigationBar
/// ============================================================

class NavigationExample2 extends StatefulWidget {
  const NavigationExample2({super.key});

  @override
  State<NavigationExample2> createState() => _NavigationExample2State();
}

class _NavigationExample2State extends State<NavigationExample2> {
  int _currentIndex = 0;

  // Liste des pages avec la nouvelle page média
  final List<Widget> _pages = [
    const Center(child: Text('Page Accueil')),
    const MediaShopWrapper(groupId: 'all'), // 👈 Nouvelle page
    const Center(child: Text('Page Profil')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Médias',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

/// ============================================================
/// OPTION 3: Route nommée dans GetX / Named Routes
/// ============================================================

class NavigationExample3 {
  // Dans votre configuration de routes (main.dart ou routes.dart)
  static const String mediaShop = '/media-shop';

  // Configuration GetX
  static List<GetPage<dynamic>> getPages = [
    GetPage(
      name: mediaShop,
      page: () => const MediaShopWrapper(groupId: 'all'),
    ),
  ];

  // Ou avec MaterialApp routes
  static Map<String, WidgetBuilder> routes = {
    mediaShop: (context) => const MediaShopWrapper(groupId: 'all'),
  };

  // Usage
  void navigateToMediaShop(BuildContext context) {
    // Avec GetX:
    // Get.toNamed(mediaShop);

    // Avec Navigator standard:
    Navigator.pushNamed(context, mediaShop);
  }
}

/// ============================================================
/// OPTION 4: Avec paramètre groupId dynamique
/// ============================================================

class NavigationExample4 extends StatelessWidget {
  const NavigationExample4({super.key});

  void _openGalleryForGroup(BuildContext context, String groupId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MediaShopWrapper(groupId: groupId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groupes de carnaval')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Akiyo'),
            subtitle: const Text('45 galeries'),
            onTap: () => _openGalleryForGroup(context, 'akiyo'),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Voukoum'),
            subtitle: const Text('32 galeries'),
            onTap: () => _openGalleryForGroup(context, 'voukoum'),
          ),
          ListTile(
            leading: const Icon(Icons.all_inclusive),
            title: const Text('Toutes les galeries'),
            subtitle: const Text('Voir toutes les photos'),
            onTap: () => _openGalleryForGroup(context, 'all'),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// OPTION 5: Badge panier global (AppBar)
/// ============================================================

// Pour afficher un badge panier dans l'AppBar de toute l'app,
// il faut wrapper toute l'app avec GalleryCartScope

class MyAppWithGlobalCart extends StatefulWidget {
  const MyAppWithGlobalCart({super.key});

  @override
  State<MyAppWithGlobalCart> createState() => _MyAppWithGlobalCartState();
}

class _MyAppWithGlobalCartState extends State<MyAppWithGlobalCart> {
  late final GalleryCartProvider _cartProvider;

  @override
  void initState() {
    super.initState();
    _cartProvider = GalleryCartProvider();
  }

  @override
  void dispose() {
    _cartProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GalleryCartScope(
      notifier: _cartProvider,
      child: MaterialApp(
        home: const HomePageWithCartBadge(),
        // ... routes, etc.
      ),
    );
  }
}

class HomePageWithCartBadge extends StatelessWidget {
  const HomePageWithCartBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Accès au panier depuis n'importe où dans l'app
    final cart = GalleryCartScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon App'),
        actions: [
          // Badge panier dans l'AppBar
          AnimatedBuilder(
            animation: cart,
            builder: (context, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined),
                    onPressed: () {
                      // Ouvrir page panier ou modal
                    },
                  ),
                  if (cart.cartCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${cart.cartCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: const Center(child: Text('Contenu')),
    );
  }
}

/// ============================================================
/// NOTES IMPORTANTES
/// ============================================================
///
/// 1. Si vous utilisez MediaShopWrapper isolément (Option 1-4),
///    le panier sera perdu lors de la navigation back.
///
/// 2. Pour un panier persistant dans toute l'app, utilisez
///    l'Option 5 (wrapper au niveau MaterialApp).
///
/// 3. Pour sauvegarder le panier (SharedPreferences, etc.),
///    modifiez GalleryCartProvider pour ajouter la persistance.
///
/// 4. Pour le checkout Stripe, modifiez la méthode
///    _openCartSheet() dans media_galleries_page_v2.dart
