import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cart_service.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';
import 'shop_body.dart';
import 'cart_page.dart';

class ShopUiPage extends StatefulWidget {
  const ShopUiPage({super.key, this.groupId});

  final String? groupId;

  @override
  State<ShopUiPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopUiPage> {
  final String _category = 'Tous';
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId;
    CartService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: HoneycombBackground(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: CartService.instance,
                  builder: (context, _) {
                    final itemCount = CartService.instance.items.length;
                    return RainbowHeader(
                      title: 'La Boutique',
                      titleStyle: const TextStyle(
                        fontFamily: 'MASLIVEBrushV2',
                        fontSize: 46,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      trailing: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CartPage(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                            ),
                          ),
                          if (itemCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.pink,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    '$itemCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: ShopBodyUnderHeader(
                  category: _category,
                  groupId: _selectedGroupId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}