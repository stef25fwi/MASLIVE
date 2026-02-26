import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/snack/top_snack_bar.dart';

class BusinessAccountPage extends StatefulWidget {
  const BusinessAccountPage({super.key});

  @override
  State<BusinessAccountPage> createState() => _BusinessAccountPageState();
}

class _BusinessAccountPageState extends State<BusinessAccountPage> {
  bool _loadingStripe = false;
  String? _stripeError;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-east1');

  Future<void> _startOrResumeOnboarding() async {
    setState(() {
      _loadingStripe = true;
      _stripeError = null;
    });

    try {
      final callable = _functions.httpsCallable(
        'createBusinessConnectOnboardingLink',
      );
      final res = await callable.call(<String, dynamic>{});
      final data = res.data;

      final url = (data is Map) ? data['url'] : null;
      if (url is! String || url.isEmpty) {
        throw Exception('URL Stripe invalide');
      }

      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw Exception('Impossible d\'ouvrir le navigateur');
      }
    } catch (e) {
      setState(() => _stripeError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingStripe = false);
    }
  }

  Future<void> _refreshStripeStatus() async {
    setState(() {
      _loadingStripe = true;
      _stripeError = null;
    });

    try {
      final callable = _functions.httpsCallable('refreshBusinessConnectStatus');
      await callable.call(<String, dynamic>{});

      if (!mounted) return;
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('Statut Stripe mis à jour')),
      );
    } catch (e) {
      setState(() => _stripeError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingStripe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compte professionnel')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Connectez-vous pour accéder à votre compte professionnel.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      );
    }

    final businessRef = FirebaseFirestore.instance
        .collection('businesses')
        .doc(user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Compte professionnel')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: businessRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Impossible de charger votre demande professionnelle.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snap.error.toString(),
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          final data = snap.data?.data();
          if (data == null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Vous n\'avez pas encore de compte professionnel.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/business-request'),
                    icon: const Icon(Icons.business_outlined),
                    label: const Text('Faire une demande'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Après validation par un admin, vous pourrez configurer Stripe Connect Express.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            );
          }

          final companyName = (data['companyName'] ?? '').toString();
          final siret = (data['siret'] ?? '').toString();
          final status = (data['status'] ?? 'pending').toString();
          final rejectionReason = (data['rejectionReason'] ?? '').toString();

          final stripe = (data['stripe'] is Map)
              ? (data['stripe'] as Map)
              : null;
          final accountId = stripe?['accountId'] as String?;
          final detailsSubmitted = stripe?['detailsSubmitted'] == true;
          final chargesEnabled = stripe?['chargesEnabled'] == true;
          final payoutsEnabled = stripe?['payoutsEnabled'] == true;

          Color chipColor;
          String chipLabel;
          switch (status) {
            case 'approved':
              chipColor = Colors.green;
              chipLabel = 'Validé';
              break;
            case 'rejected':
              chipColor = Colors.red;
              chipLabel = 'Refusé';
              break;
            case 'pending':
            default:
              chipColor = Colors.orange;
              chipLabel = 'En attente';
              break;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.business),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              companyName.isEmpty ? 'Entreprise' : companyName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(chipLabel),
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            backgroundColor: chipColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('SIRET: $siret'),
                    ],
                  ),
                ),
              ),

              if (status == 'pending')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Votre demande est en cours de validation.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vous pouvez corriger votre nom d\'entreprise/SIRET, mais cela ne valide pas automatiquement la demande.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/business-request'),
                          child: const Text('Modifier (reste en attente)'),
                        ),
                      ],
                    ),
                  ),
                ),

              if (status == 'rejected')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Votre demande a été refusée.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (rejectionReason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Motif: $rejectionReason'),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'En modifiant et envoyant à nouveau, votre demande repasse en attente de validation.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/business-request'),
                          child: const Text('Modifier et re-soumettre'),
                        ),
                      ],
                    ),
                  ),
                ),

              if (status == 'approved')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paiements (Stripe Connect Express)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Finalisez Stripe pour recevoir des paiements et des virements.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Text('Compte Stripe: ${accountId ?? "non configuré"}'),
                        const SizedBox(height: 8),
                        Text(
                          'Dossier complété: ${detailsSubmitted ? "oui" : "non"}',
                        ),
                        Text(
                          'Encaissement activé: ${chargesEnabled ? "oui" : "non"}',
                        ),
                        Text(
                          'Virements activés: ${payoutsEnabled ? "oui" : "non"}',
                        ),
                        if (_stripeError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _stripeError!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _loadingStripe
                                    ? null
                                    : _startOrResumeOnboarding,
                                icon: const Icon(Icons.open_in_new),
                                label: Text(
                                  accountId == null
                                      ? 'Configurer Stripe'
                                      : 'Ouvrir Stripe',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'Rafraîchir',
                              onPressed: _loadingStripe
                                  ? null
                                  : _refreshStripeStatus,
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        if (_loadingStripe) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
