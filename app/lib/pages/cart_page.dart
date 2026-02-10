import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../session/require_signin.dart';
import '../session/session_scope.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'checkout/storex_checkout_stripe.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  static const _headerGradient = LinearGradient(
    colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  Future<void> _checkout(BuildContext context, String userId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final checkoutUrl = await CartService.instance.createCheckoutSession(userId);

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('URL de checkout manquante');
      }

      final uri = Uri.parse(checkoutUrl);
      if (!await canLaunchUrl(uri)) {
        throw Exception('Impossible d\'ouvrir l\'URL de paiement');
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      String message = 'Erreur lors de la création du paiement';
      
      switch (e.code) {
        case 'unauthenticated':
          message = 'Vous devez être connecté pour commander';
          break;
        case 'permission-denied':
          message = 'Accès refusé. Vérifiez vos permissions.';
          break;
        case 'failed-precondition':
          message = 'Votre panier est vide';
          break;
        case 'resource-exhausted':
          message = 'Trop de requêtes. Réessayez dans quelques instants.';
          break;
        case 'unavailable':
          message = 'Service temporairement indisponible. Réessayez.';
          break;
        default:
          message = e.message ?? 'Erreur inconnue: ${e.code}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Réessayer',
            textColor: Colors.white,
            onPressed: () {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId != null) {
                _checkout(context, currentUserId);
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Réessayer',
            textColor: Colors.white,
            onPressed: () {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId != null) {
                _checkout(context, currentUserId);
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: CartService.instance,
          builder: (context, _) {
            final items = CartService.instance.items;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Barre titre + total (style référence boutique photo)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: _headerGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Retour',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Panier',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          CartService.instance.totalLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (items.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Ton panier est vide.',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: item.displayImage.isEmpty
                                      ? Container(
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
                                          child: const Icon(
                                            Icons.image_outlined,
                                          ),
                                        )
                                      : item.isLocalAsset
                                      ? Image.asset(
                                          item.displayImage,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.network(
                                          item.displayImage,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Taille ${item.size} • ${item.color}',
                                      style: TextStyle(
                                        color: Colors.black.withValues(
                                          alpha: 0.70,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _QtyButton(
                                          icon: Icons.remove,
                                          onTap: () =>
                                              CartService.instance.setQuantity(
                                                item.key,
                                                item.quantity - 1,
                                              ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        _QtyButton(
                                          icon: Icons.add,
                                          onTap: () =>
                                              CartService.instance.setQuantity(
                                                item.key,
                                                item.quantity + 1,
                                              ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: 'Retirer',
                                          onPressed: () => CartService.instance
                                              .removeKey(item.key),
                                          icon: const Icon(Icons.close),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: items.isEmpty
                              ? null
                              : () => CartService.instance.clear(),
                          child: const Text('Vider'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: items.isEmpty
                              ? null
                              : () => requireSignIn(
                                  context,
                                  session: session,
                                  onSignedIn: () {
                                    final userId = FirebaseAuth
                                        .instance.currentUser?.uid;
                                    if (userId == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Utilisateur introuvable'),
                                        ),
                                      );
                                      return;
                                    }

                                    StorexCheckoutFlow.start(context);
                                  },
                                ),
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Commander'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18)),
      ),
    );
  }
}
