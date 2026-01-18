import 'package:flutter/material.dart';

import '../pages/paywall_page.dart';
import '../services/premium_service.dart';

class PremiumGate extends StatelessWidget {
  const PremiumGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumService.instance.isPremium,
      builder: (_, isPremium, _) {
        if (isPremium) return child;
        return Center(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaywallPage()),
            ),
            icon: const Icon(Icons.stars_rounded),
            label: const Text('Débloquer Premium'),
          ),
        );
      },
    );
  }
}
