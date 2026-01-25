import 'package:flutter/material.dart';

import 'shop_page.dart';

class GroupShopPage extends StatelessWidget {
  const GroupShopPage({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context) {
    return ShopPixelPerfectPage(groupId: groupId);
  }
}
