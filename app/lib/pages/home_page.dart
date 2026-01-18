import 'package:flutter/material.dart';

import 'home_map_page.dart';

@Deprecated('Doublon: utiliser HomeMapPage (route "/").')
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeMapPage();
  }
}
