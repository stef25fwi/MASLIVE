import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/media_order_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/repositories/photographer_complete_flow_repository.dart';

class PhotographerFinancePanel extends StatefulWidget {
  const PhotographerFinancePanel({
    super.key,
    required this.profile,
    required this.repository,
  });

  final PhotographerProfileModel profile;
  final PhotographerCompleteFlowRepository repository;

  @override
  State<PhotographerFinancePanel> createState() => _PhotographerFinancePanelState();
}

class _PhotographerFinancePanelState extends State<PhotographerFinancePanel> {
  List<MediaOrderModel> _orders = const <MediaOrderModel>[];
  List<Map<String, dynamic>> _payouts = const <Map<String, dynamic>>[];
  DateTimeRange? _range;
  String _paymentStatus = 'all';
  String _payoutStatus = 'all';
  bool _loading = true;
  bool _exporting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.repository.loadOrders(widget.profile.photographerId),
        widget.repository.loadPayouts(widget.profile.photographerId),
      ]);
      if (!mounted) return;
      setState(() {
        _orders = results[0] as List<MediaOrderModel>;
        _payouts = results[1] as List<Map<String, dynamic>>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MediaOrderModel> get _filteredOrders {
    return _orders.where((order) {
      final date = order.paidAt ?? order.createdAt;
      if (_range != null) {
        final end = DateTime(
          _range!.end.year,
          _range!.end.month,
          _range!.end.day,
          23,
          59,
          59,
        );
        if (date.isBefore(_range!.start) || date.isAfter(end)) return false;
      }
      if (_paymentStatus != 'all' && order.paymentStatus.name != _paymentStatus) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> get _filteredPayouts {
    return _payouts.where((row) {
      if (_payoutStatus != 'all' && row['status']?.toString() != _payoutStatus) {
        return false;
      }
      if (_range != null) {
        final date = _date(row['createdAt']);
        final end = DateTime(
          _range!.end.year,
          _range!.end.month,
          _range!.end.day,
          23,
          59,
          59,
        );
        if (date.isBefore(_range!.start) || date.isAfter(end)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  double _payoutTotal(Iterable<String> statuses) => _payouts
      .where((row) => statuses.contains(row['status']?.toString() ?? ''))
      .fold<double>(
        0,
        (total, row) => total +
            ((row['net'] as num?)?.toDouble() ??
                (row['photographerAmount'] as num?)?.toDouble() ??
                0),
      );

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (range != null) setState(() => _range = range);
  }

  Future<void> _export(String kind) async {
    setState(() => _exporting = true);
    try {
      final result = await widget.repository.generateExport(
        photographerId: widget.profile.photographerId,
        kind: kind,
        from: _range?.start,
        to: _range?.end,
      );
      final date = DateTime.now().toIso8601String().split('T').first;
      if (kind == 'invoice') {
        final text = result['invoiceText']?.toString() ?? '';
        await SharePlus.instance.share(
          ShareParams(
            title: 'Relevé photographe MASLIVE',
            subject: result['invoiceNumber']?.toString(),
            files: <XFile>[
              XFile.fromData(
                utf8.encode(text),
                mimeType: 'text/plain',
              ),
            ],
            fileNameOverrides: <String>['releve_maslive_$date.txt'],
          ),
        );
      } else {
        final csv = result['csv']?.toString() ?? '';
        final fileName = kind == 'clients'
            ? 'clients_maslive_$date.csv'
            : kind == 'accounting'
                ? 'comptabilite_maslive_$date.csv'
                : 'ventes_maslive_$date.csv';
        await SharePlus.instance.share(
          ShareParams(
            title: 'Export MASLIVE',
            files: <XFile>[
              XFile.fromData(
                utf8.encode('\uFEFF$csv'),
                mimeType: 'text/csv',
              ),
            ],
            fileNameOverrides: <String>[fileName],
          ),
        );
      }
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text.replaceFirst('Bad state: ', '')),
        backgroundColor: error ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('Réessayer : $_error'),
        ),
      );
    }
    final orders = _filteredOrders;
    final payouts = _filteredPayouts;
    final gross = orders.fold<double>(0, (total, order) => total + order.total);
    final fees = orders.fold<double>(
      0,
      (total, order) => total + order.platformFee + order.stripeFee,
    );
    final net = orders.fold<double>(
      0,
      (total, order) => total + order.photographerNetTotal,
    );
    final upcoming = _payouts.where((row) {
      final status = row['status']?.toString();
      return status == 'pending_transfer' || status == 'available';
    }).toList(growable: false)
      ..sort((a, b) => _date(a['availableAt'] ?? a['scheduledAt'] ?? a['createdAt'])
          .compareTo(_date(b['availableAt'] ?? b['scheduledAt'] ?? b['createdAt'])));

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _MetricCard(label: 'Disponible', value: '${_payoutTotal(const <String>['pending_transfer', 'available']).toStringAsFixed(2)} €'),
              _MetricCard(label: 'En attente', value: '${_payoutTotal(const <String>['processing', 'pending', 'blocked_connect_required', 'transfer_failed']).toStringAsFixed(2)} €'),
              _MetricCard(label: 'Reversé', value: '${_payoutTotal(const <String>['transferred', 'paid']).toStringAsFixed(2)} €'),
              _MetricCard(label: 'CA filtré', value: '${gross.toStringAsFixed(2)} €'),
              _MetricCard(label: 'Frais filtrés', value: '${fees.toStringAsFixed(2)} €'),
              _MetricCard(label: 'Net filtré', value: '${net.toStringAsFixed(2)} €'),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _range == null
                      ? 'Toutes les périodes'
                      : '${_formatDate(_range!.start)} → ${_formatDate(_range!.end)}',
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentStatus,
                  decoration: const InputDecoration(labelText: 'Paiements'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'all', child: Text('Tous')),
                    DropdownMenuItem(value: 'pending', child: Text('En attente')),
                    DropdownMenuItem(value: 'paid', child: Text('Payés')),
                    DropdownMenuItem(value: 'failed', child: Text('Échoués')),
                    DropdownMenuItem(value: 'refunded', child: Text('Remboursés')),
                  ],
                  onChanged: (value) => setState(() => _paymentStatus = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: _payoutStatus,
                  decoration: const InputDecoration(labelText: 'Reversements'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'all', child: Text('Tous')),
                    DropdownMenuItem(value: 'pending_transfer', child: Text('Disponibles')),
                    DropdownMenuItem(value: 'processing', child: Text('En traitement')),
                    DropdownMenuItem(value: 'transferred', child: Text('Reversés')),
                    DropdownMenuItem(value: 'blocked_connect_required', child: Text('Stripe requis')),
                    DropdownMenuItem(value: 'transfer_failed', child: Text('Échecs')),
                  ],
                  onChanged: (value) => setState(() => _payoutStatus = value ?? 'all'),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _exporting ? null : () => _export('sales'),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('CSV ventes'),
              ),
              FilledButton.tonalIcon(
                onPressed: _exporting ? null : () => _export('accounting'),
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('Export comptable'),
              ),
              FilledButton.tonalIcon(
                onPressed: _exporting ? null : () => _export('clients'),
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('Export clients'),
              ),
              FilledButton.icon(
                onPressed: _exporting ? null : () => _export('invoice'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Générer un relevé'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Calendrier des prochains reversements',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.event_available_outlined),
                title: Text('Aucun reversement programmé'),
                subtitle: Text('Les nouvelles ventes apparaîtront après confirmation Stripe.'),
              ),
            )
          else
            for (final row in upcoming.take(10))
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_repeat_outlined),
                  title: Text(
                    '${((row['net'] as num?)?.toDouble() ?? (row['photographerAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ${row['currency'] ?? 'EUR'}',
                  ),
                  subtitle: Text(
                    'Prévu le ${_formatDate(_date(row['availableAt'] ?? row['scheduledAt'] ?? row['createdAt']))} • ${row['status']}',
                  ),
                ),
              ),
          const SizedBox(height: 22),
          Text(
            'Commandes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (orders.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aucune commande pour les filtres choisis.'),
              ),
            )
          else
            for (final order in orders)
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text('${order.total.toStringAsFixed(2)} ${order.currency}'),
                  subtitle: Text(
                    '${order.paymentStatus.name} • ${order.deliveryStatus.name} • ${_formatDate(order.createdAt)}',
                  ),
                  trailing: Text(
                    '${order.photographerNetTotal.toStringAsFixed(2)} € net',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  children: <Widget>[
                    for (final item in order.items.where(
                      (item) => item.photographerId == widget.profile.photographerId,
                    ))
                      ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} € • galerie ${item.galleryId ?? '—'}',
                        ),
                        trailing: Text('${item.lineSubtotal.toStringAsFixed(2)} €'),
                      ),
                    ListTile(
                      title: const Text('Commission plateforme'),
                      trailing: Text('${order.platformFee.toStringAsFixed(2)} €'),
                    ),
                    ListTile(
                      title: const Text('Frais Stripe'),
                      trailing: Text('${order.stripeFee.toStringAsFixed(2)} €'),
                    ),
                    ListTile(
                      title: const Text('Net photographe'),
                      trailing: Text(
                        '${order.photographerNetTotal.toStringAsFixed(2)} €',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 22),
          Text(
            'Journal des reversements',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (payouts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aucun mouvement de reversement.'),
              ),
            )
          else
            for (final row in payouts)
              Card(
                child: ListTile(
                  leading: Icon(
                    row['status'] == 'transferred'
                        ? Icons.check_circle_outline
                        : row['status'] == 'transfer_failed'
                            ? Icons.error_outline
                            : Icons.schedule_outlined,
                  ),
                  title: Text(
                    '${((row['net'] as num?)?.toDouble() ?? (row['photographerAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ${row['currency'] ?? 'EUR'}',
                  ),
                  subtitle: Text(
                    '${row['status'] ?? 'pending'} • ${_formatDate(_date(row['createdAt']))}',
                  ),
                  trailing: Text(row['stripeTransferId']?.toString() ?? ''),
                ),
              ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
