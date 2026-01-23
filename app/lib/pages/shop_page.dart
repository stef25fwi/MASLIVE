import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cart_service.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';
import 'shop_body.dart';

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
              const SliverToBoxAdapter(
                child: RainbowHeader(
                  title: 'La Boutique',
                  titleStyle: TextStyle(
                    fontFamily: 'MASLIVEBrushV2',
                    fontSize: 46,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  trailing: Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                  ),
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