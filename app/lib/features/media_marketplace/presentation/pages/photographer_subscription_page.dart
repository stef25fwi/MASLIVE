import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../ui/theme/maslive_theme.dart';
import '../../core/constants/media_marketplace_pricing.dart';
import '../../data/models/photographer_plan_model.dart';
import '../controllers/photographer_subscription_controller.dart';
import '../widgets/media_marketplace_message_card.dart';
import '../widgets/media_marketplace_section_header.dart';
import '../widgets/media_marketplace_shell.dart';

class PhotographerSubscriptionPage extends StatelessWidget {
  const PhotographerSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhotographerSubscriptionController>(
      create: (_) {
        final controller = PhotographerSubscriptionController();
        Future<void>.microtask(controller.loadForCurrentOwner);
        return controller;
      },
      child: const _PhotographerSubscriptionView(),
    );
  }
}

class _PhotographerSubscriptionView extends StatefulWidget {
  const _PhotographerSubscriptionView();

  @override
  State<_PhotographerSubscriptionView> createState() =>
      _PhotographerSubscriptionViewState();
}

class _PhotographerSubscriptionViewState
    extends State<_PhotographerSubscriptionView> {
  String _billingInterval = 'month';
  String? _creditPhotographerId;
  Future<Map<String, dynamic>>? _creditFuture;

  Future<Map<String, dynamic>> _loadAiCredits(String photographerId) async {
    final response = await FirebaseFunctions.instanceFor(region: 'us-east1')
        .httpsCallable('getPhotographerAiCreditBalance')
        .call(<String, dynamic>{'photographerId': photographerId});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>>? _creditBalanceFor(String? photographerId) {
    final normalized = photographerId?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (_creditFuture == null || _creditPhotographerId != normalized) {
      _creditPhotographerId = normalized;
      _creditFuture = _loadAiCredits(normalized);
    }
    return _creditFuture;
  }

  void _refreshCredits() {
    final id = _creditPhotographerId;
    if (id == null || id.isEmpty) return;
    setState(() => _creditFuture = _loadAiCredits(id));
  }

  Future<void> _openCheckout(
    BuildContext context,
    PhotographerSubscriptionController controller, {
    required String planId,
    required String billingInterval,
  }) async {
    final url = await controller.startCheckout(
      planId: planId,
      billingInterval: billingInterval,
    );
    if (!context.mounted) return;
    if (controller.activatedWithoutCheckout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formule Découverte activée.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (url == null || url.trim().isEmpty) return;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir le paiement sécurisé.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhotographerSubscriptionController>();
    final activePlanCode =
        controller.activeSubscription?.quotaSnapshot.planCode ??
            controller.profile?.activePlanId ??
            'discovery';
    final creditFuture =
        _creditBalanceFor(controller.profile?.photographerId);

    return Scaffold(
      backgroundColor: MasliveTheme.surfaceAlt,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: MasliveTheme.backgroundWash),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 84),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                      child: MediaMarketplaceBrandHeader(
                        subtitle: 'ABONNEMENT PHOTO',
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: controller.loading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              children: <Widget>[
                                if (controller.error != null)
                                  MediaMarketplaceMessageCard.error(
                                    controller.error!,
                                  ),
                                _ActivePlanCard(
                                  planCode: activePlanCode,
                                  status:
                                      controller.activeSubscription?.status.name,
                                ),
                                const SizedBox(height: 14),
                                _AiCreditBalanceCard(
                                  future: creditFuture,
                                  onRefresh: _refreshCredits,
                                ),
                                const SizedBox(height: 22),
                                MediaMarketplaceSectionHeader(
                                  title: 'Formules photographes',
                                  subtitle:
                                      'L’abonnement finance le stockage et les outils. Les analyses IA utilisent un solde séparé.',
                                  trailing: SegmentedButton<String>(
                                    segments: const <ButtonSegment<String>>[
                                      ButtonSegment<String>(
                                        value: 'month',
                                        label: Text('Mensuel'),
                                      ),
                                      ButtonSegment<String>(
                                        value: 'year',
                                        label: Text('Annuel'),
                                      ),
                                    ],
                                    selected: <String>{_billingInterval},
                                    onSelectionChanged: (selection) {
                                      setState(
                                        () => _billingInterval =
                                            selection.first,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final columns = constraints.maxWidth >= 1100
                                        ? 4
                                        : constraints.maxWidth >= 720
                                            ? 2
                                            : 1;
                                    final cardWidth = columns == 1
                                        ? constraints.maxWidth
                                        : (constraints.maxWidth -
                                                ((columns - 1) * 12)) /
                                            columns;
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: controller.plans.map((plan) {
                                        final spec =
                                            MediaMarketplacePricing.planFor(
                                          plan.code,
                                        );
                                        return SizedBox(
                                          width: cardWidth,
                                          child: _PlanCard(
                                            plan: plan,
                                            spec: spec,
                                            annual:
                                                _billingInterval == 'year',
                                            active:
                                                spec.code == activePlanCode,
                                            loading:
                                                controller.processingCheckout,
                                            onSelect: () => _openCheckout(
                                              context,
                                              controller,
                                              planId: plan.planId,
                                              billingInterval:
                                                  _billingInterval,
                                            ),
                                          ),
                                        );
                                      }).toList(growable: false),
                                    );
                                  },
                                ),
                                if (controller.plans.isEmpty)
                                  MediaMarketplaceMessageCard.empty(
                                    title: 'Catalogue indisponible',
                                    message:
                                        'Les tarifs MASLIVE seront rechargés automatiquement.',
                                    icon: Icons.workspace_premium_outlined,
                                  ),
                                const SizedBox(height: 26),
                                const MediaMarketplaceSectionHeader(
                                  title: 'Extensions et crédits IA',
                                  subtitle:
                                      'Capacité récurrente, crédits à achat unique ou renfort événementiel de 30 jours.',
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth >= 1050
                                        ? (constraints.maxWidth - 24) / 3
                                        : constraints.maxWidth >= 680
                                            ? (constraints.maxWidth - 12) / 2
                                            : constraints.maxWidth;
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: MediaMarketplacePricing
                                          .storageExtensions
                                          .map(
                                            (extension) => SizedBox(
                                              width: width,
                                              child: _ExtensionCard(
                                                extension: extension,
                                                loading: controller
                                                    .processingCheckout,
                                                onSelect: () => _openCheckout(
                                                  context,
                                                  controller,
                                                  planId:
                                                      'extension:${extension.code}',
                                                  billingInterval:
                                                      extension.recurring
                                                          ? 'month'
                                                          : 'one_time',
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(growable: false),
                                    );
                                  },
                                ),
                                const SizedBox(height: 26),
                                const _BusinessModelReminder(),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              MediaMarketplaceVerticalNav(
                selected: MediaMarketplaceNavSection.photographer,
                onOpenCatalog: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: const <String, dynamic>{'initialTab': 0},
                ),
                onOpenPhotographer: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: const <String, dynamic>{'initialTab': 3},
                ),
                onOpenCart: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: const <String, dynamic>{'initialTab': 1},
                ),
                onOpenDownloads: () => Navigator.pushReplacementNamed(
                  context,
                  '/media-marketplace',
                  arguments: const <String, dynamic>{'initialTab': 2},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivePlanCard extends StatelessWidget {
  const _ActivePlanCard({required this.planCode, this.status});

  final String planCode;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final plan = MediaMarketplacePricing.planFor(planCode);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.workspace_premium_rounded),
        ),
        title: Text('Formule active : ${plan.name}'),
        subtitle: Text(
          '${plan.maxPublishedPhotos} photos • '
          '${(plan.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go • '
          '${(plan.commissionRate * 100).round()} % de commission'
          '${status == null ? '' : ' • $status'}\n'
          'Les crédits IA sont achetés séparément et ne sont débités que lors d’une analyse.',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _AiCreditBalanceCard extends StatelessWidget {
  const _AiCreditBalanceCard({
    required this.future,
    required this.onRefresh,
  });

  final Future<Map<String, dynamic>>? future;
  final VoidCallback onRefresh;

  int _remaining(Map<String, dynamic> data, String mode) {
    final raw = data[mode];
    if (raw is! Map) return 0;
    return (raw['remaining'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.auto_awesome_outlined),
          title: Text('Crédits IA'),
          subtitle: Text('Crée ou charge ton profil photographe pour consulter le solde.'),
        ),
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Chargement des crédits IA'),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Solde IA indisponible'),
              subtitle: Text('${snapshot.error}'),
              trailing: IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final basic = _remaining(data, 'basic');
        final advanced = _remaining(data, 'advanced');
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.auto_awesome_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Solde de crédits IA',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualiser',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _CreditMetric(
                      label: 'OCR / couleurs',
                      value: '$basic',
                      icon: Icons.document_scanner_outlined,
                    ),
                    _CreditMetric(
                      label: 'Analyse avancée',
                      value: '$advanced',
                      icon: Icons.face_retouching_natural_outlined,
                    ),
                    const _CreditMetric(
                      label: 'Coût prévisionnel',
                      value: '0,01 € / analyse',
                      icon: Icons.savings_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Première analyse : 1 crédit • Réanalyse manuelle : 1 crédit • '
                  'déplacement, prix et tags : 0 crédit.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreditMetric extends StatelessWidget {
  const _CreditMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.spec,
    required this.annual,
    required this.active,
    required this.loading,
    required this.onSelect,
  });

  final PhotographerPlanModel plan;
  final PhotographerPlanSpec spec;
  final bool annual;
  final bool active;
  final bool loading;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final recommended = spec.code == 'pro';
    final price = annual ? plan.annualPrice : plan.monthlyPrice;
    return Card(
      elevation: recommended ? 5 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: active
              ? Colors.green
              : recommended
                  ? MasliveTheme.pink
                  : Colors.black12,
          width: active || recommended ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (recommended) const Chip(label: Text('RECOMMANDÉ')),
                if (active) const Chip(label: Text('ACTIF')),
              ],
            ),
            const SizedBox(height: 8),
            Text(plan.description),
            const SizedBox(height: 12),
            Text(
              price == 0
                  ? 'Gratuit'
                  : '${price.toStringAsFixed(2)} € / ${annual ? 'an' : 'mois'}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            _FeatureLine('${spec.maxPublishedPhotos} photos actives'),
            _FeatureLine(
              '${(spec.maxStorageBytes / (1024 * 1024 * 1024)).round()} Go de stockage',
            ),
            _FeatureLine('${spec.maxActiveGalleries} galeries actives'),
            _FeatureLine(spec.qualityLabel),
            _FeatureLine(
              'Fichier max ${(spec.maxFileBytes / (1024 * 1024)).round()} Mo',
            ),
            _FeatureLine('Conservation ${spec.retentionDays} jours'),
            _FeatureLine(
              'Commission MASLIVE ${(spec.commissionRate * 100).round()} %',
            ),
            const _FeatureLine('Crédits IA achetés séparément'),
            for (final feature in spec.features) _FeatureLine(feature),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: active || loading ? null : onSelect,
                child: Text(
                  active
                      ? 'Formule active'
                      : spec.monthlyPrice == 0
                          ? 'Activer gratuitement'
                          : 'Choisir ${spec.name}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  const _ExtensionCard({
    required this.extension,
    required this.loading,
    required this.onSelect,
  });

  final StorageExtensionSpec extension;
  final bool loading;
  final VoidCallback onSelect;

  IconData get _icon {
    if (extension.kind == 'ai_basic') return Icons.document_scanner_outlined;
    if (extension.kind == 'ai_advanced') {
      return Icons.face_retouching_natural_outlined;
    }
    if (extension.isEventPack) return Icons.event_available_outlined;
    return Icons.cloud_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(child: Icon(_icon)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    extension.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(extension.description),
            const SizedBox(height: 10),
            Text(
              extension.billingLabel,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final line in extension.capacityLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.check_rounded, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loading ? null : onSelect,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(
                extension.recurring ? 'Ajouter au forfait' : 'Acheter ce pack',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessModelReminder extends StatelessWidget {
  const _BusinessModelReminder();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Colors.black87,
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Modèle économique MASLIVE Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Abonnement = stockage et outils de gestion',
              style: TextStyle(color: Colors.white),
            ),
            Text(
              'Crédits IA = première analyse et réanalyses manuelles',
              style: TextStyle(color: Colors.white),
            ),
            Text(
              'Commission sur vente = paiement, trafic et téléchargement',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            Text(
              'Une photo consomme 1 emplacement actif + son volume réel. '
              'Elle ne consomme un crédit IA qu’au moment où une analyse est effectivement lancée.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
