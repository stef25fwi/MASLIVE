import 'package:flutter/material.dart';

import 'home_map_page_3d.dart';

@Deprecated('Doublon: utiliser HomeMapPage3D (route "/").')
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeMapPage3D();
  }
}
