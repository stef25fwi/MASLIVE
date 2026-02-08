import 'package:flutter/material.dart';

import 'storex_shop_page.dart';

class GroupShopPage extends StatelessWidget {
  const GroupShopPage({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context) {
    return const StorexShopPage(
      shopId: "global",
      groupId: "MASLIVE",
    );
  }
}
