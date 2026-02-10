import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/premium_service.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  Offerings? _offerings;
  bool _loading = true;
  String? _error;

  static const String _monthlyPriceId = String.fromEnvironment(
    'STRIPE_PREMIUM_MONTHLY_PRICE_ID',
    defaultValue: '',
  );
  static const String _yearlyPriceId = String.fromEnvironment(
    'STRIPE_PREMIUM_YEARLY_PRICE_ID',
    defaultValue: '',
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (kIsWeb) {
        setState(() {
          _offerings = null;
          _loading = false;
        });
        return;
      }
      final offerings = await PremiumService.instance.getOfferings();
      setState(() {
        _offerings = offerings;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = PremiumService.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Premium'),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await premium.restorePurchases();
              if (mounted) nav.pop();
            },
            child: const Text(
              'Restaurer',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (kIsWeb) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Débloque MASLIVE Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paiement via Stripe (abonnement).',
              style: TextStyle(color: Colors.white70, height: 1.3),
            ),
            const SizedBox(height: 18),
            if (_monthlyPriceId.isEmpty || _yearlyPriceId.isEmpty)
              const Text(
                '⚠️ Configuration manquante: ajoute --dart-define=STRIPE_PREMIUM_MONTHLY_PRICE_ID=price_... et --dart-define=STRIPE_PREMIUM_YEARLY_PRICE_ID=price_... au build web.',
                style: TextStyle(color: Colors.white70, height: 1.3),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: 2,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final isMonthly = i == 0;
                    final priceId = isMonthly ? _monthlyPriceId : _yearlyPriceId;
                    final title = isMonthly ? 'Premium Mensuel' : 'Premium Annuel';
                    final desc = isMonthly
                        ? 'Accès premium renouvelé chaque mois.'
                        : 'Accès premium renouvelé chaque année.';

                    return _PackageTile(
                      title: title,
                      subtitle: desc,
                      price: 'Stripe',
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final origin = Uri.base.origin;
                          final successUrl = Uri.parse('$origin/#/paywall?stripe=success');
                          final cancelUrl = Uri.parse('$origin/#/paywall?stripe=cancel');

                          await PremiumService.instance.startStripeSubscriptionCheckout(
                            priceId: priceId,
                            successUrl: successUrl,
                            cancelUrl: cancelUrl,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('Checkout échoué: $e')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            ValueListenableBuilder<bool>(
              valueListenable: PremiumService.instance.isPremium,
              builder: (_, isPremium, _) {
                return Text(
                  isPremium ? '✅ Premium actif' : 'Premium inactif',
                  style: TextStyle(
                    color: isPremium ? Colors.white : Colors.white54,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    final offering = _offerings?.current;
    final packages = offering?.availablePackages ?? [];

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Débloque MASLIVE Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Couches avancées, favoris, alertes, options carte premium…',
            style: TextStyle(color: Colors.white70, height: 1.3),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: packages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = packages[i];
                final price = p.storeProduct.priceString;
                final title = p.storeProduct.title;
                final desc = p.storeProduct.description;

                return _PackageTile(
                  title: title,
                  subtitle: desc,
                  price: price,
                  onTap: () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await PremiumService.instance.purchasePackage(p);
                      if (mounted) nav.pop();
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Achat annulé/échoué: $e')),
                      );
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: PremiumService.instance.isPremium,
            builder: (_, isPremium, _) {
              return Text(
                isPremium ? '✅ Premium actif' : 'Premium inactif',
                style: TextStyle(
                  color: isPremium ? Colors.white : Colors.white54,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
