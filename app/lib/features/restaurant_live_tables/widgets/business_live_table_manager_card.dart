import 'package:flutter/material.dart';

import '../../../services/premium_service.dart';
import '../../../ui/snack/top_snack_bar.dart';
import '../models/live_table_state.dart';
import '../repositories/restaurant_live_table_repository.dart';
import '../services/live_table_status_service.dart';
import 'business_restaurant_selector_sheet.dart';
import 'live_table_pro_panel.dart';
import 'live_table_status_badge.dart';

class BusinessLiveTableManagerCard extends StatefulWidget {
  const BusinessLiveTableManagerCard({
    super.key,
    required this.businessData,
  });

  final Map<String, dynamic> businessData;

  @override
  State<BusinessLiveTableManagerCard> createState() =>
      _BusinessLiveTableManagerCardState();
}

class _BusinessLiveTableManagerCardState
    extends State<BusinessLiveTableManagerCard> {
  final _availableCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  final _service = LiveTableStatusService();
  final _repository = RestaurantLiveTableRepository();

  bool _linking = false;
  bool _publishing = false;
  bool _liveEnabled = false;
  LiveTableStatus _liveStatus = LiveTableStatus.available;
  String? _statusError;
  String? _hydratedRemoteKey;
  Map<String, dynamic>? _optimisticLinkedRestaurantRef;
  Map<String, dynamic> _selectedRestaurantRef = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _hydrateLinkedPoiRef();
  }

  @override
  void didUpdateWidget(covariant BusinessLiveTableManagerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessData != widget.businessData) {
      _hydrateLinkedPoiRef();
    }
  }

  @override
  void dispose() {
    _availableCtrl.dispose();
    _capacityCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _hydrateLinkedPoiRef() {
    _optimisticLinkedRestaurantRef = null;
    _selectedRestaurantRef = _effectiveLinkedPoiRefMap;
    _hydratedRemoteKey = null;
  }

  Map<String, dynamic> get _linkedPoiRefMap {
    final raw = widget.businessData['restaurantPoiRef'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> get _effectiveLinkedPoiRefMap {
    final optimistic = _optimisticLinkedRestaurantRef;
    if (optimistic != null && optimistic.isNotEmpty) {
      return optimistic;
    }
    return _linkedPoiRefMap;
  }

  String _refKey(Map<String, dynamic> ref) {
    return [
      (ref['countryId'] ?? '').toString().trim(),
      (ref['eventId'] ?? '').toString().trim(),
      (ref['circuitId'] ?? '').toString().trim(),
      (ref['poiId'] ?? '').toString().trim(),
    ].join('|');
  }

  bool _hasIds(Map<String, dynamic> ref) {
    return (ref['countryId'] ?? '').toString().trim().isNotEmpty &&
        (ref['eventId'] ?? '').toString().trim().isNotEmpty &&
        (ref['circuitId'] ?? '').toString().trim().isNotEmpty &&
        (ref['poiId'] ?? '').toString().trim().isNotEmpty;
  }

  String get _countryId => (_selectedRestaurantRef['countryId'] ?? '').toString().trim();
  String get _eventId => (_selectedRestaurantRef['eventId'] ?? '').toString().trim();
  String get _circuitId => (_selectedRestaurantRef['circuitId'] ?? '').toString().trim();
  String get _poiId => (_selectedRestaurantRef['poiId'] ?? '').toString().trim();
  String get _restaurantName => (_selectedRestaurantRef['name'] ?? _poiId).toString().trim();

  String get _linkedCountryId => (_effectiveLinkedPoiRefMap['countryId'] ?? '').toString().trim();
  String get _linkedEventId => (_effectiveLinkedPoiRefMap['eventId'] ?? '').toString().trim();
  String get _linkedCircuitId => (_effectiveLinkedPoiRefMap['circuitId'] ?? '').toString().trim();
  String get _linkedPoiId => (_effectiveLinkedPoiRefMap['poiId'] ?? '').toString().trim();

  bool get _hasLinkedIds =>
      _countryId.isNotEmpty &&
      _eventId.isNotEmpty &&
      _circuitId.isNotEmpty &&
      _poiId.isNotEmpty;

  bool get _hasPersistedLinkedIds => _hasIds(_effectiveLinkedPoiRefMap);

  bool get _selectionMatchesLinked => _refKey(_selectedRestaurantRef) == _refKey(_effectiveLinkedPoiRefMap);

  bool get _hasBusinessLiveSubscription {
    final raw = widget.businessData['liveTableSubscription'];
    if (raw is! Map) return false;
    final status = (raw['status'] ?? '').toString().trim().toLowerCase();
    return status == 'active' || status == 'trialing';
  }

  String get _persistedLinkedKey => '$_linkedCountryId|$_linkedEventId|$_linkedCircuitId|$_linkedPoiId';

  int? _parseInt(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  Future<void> _assignRestaurantPoi() async {
    if (!_hasLinkedIds) {
      setState(() => _statusError = 'Choisissez un restaurant avant de le lier.');
      return;
    }

    setState(() {
      _linking = true;
      _statusError = null;
    });

    try {
      await _service.assignBusinessRestaurantPoi(
        countryId: _countryId,
        eventId: _eventId,
        circuitId: _circuitId,
        poiId: _poiId,
      );
      if (!mounted) return;
      setState(() {
        _optimisticLinkedRestaurantRef = Map<String, dynamic>.from(_selectedRestaurantRef);
        _hydratedRemoteKey = null;
      });
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('Restaurant lié au compte professionnel.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusError = e.toString());
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _pickRestaurant() async {
    final initialRef = _hasLinkedIds ? _selectedRestaurantRef : _effectiveLinkedPoiRefMap;
    final selection = await showBusinessRestaurantSelectorSheet(
      context,
      initialCountryId: (initialRef['countryId'] ?? '').toString(),
      initialEventId: (initialRef['eventId'] ?? '').toString(),
      initialCircuitId: (initialRef['circuitId'] ?? '').toString(),
      initialPoiId: (initialRef['poiId'] ?? '').toString(),
    );
    if (!mounted || selection == null) return;

    setState(() {
      _selectedRestaurantRef = <String, dynamic>{
        'countryId': selection.country.id,
        'eventId': selection.event.id,
        'circuitId': selection.circuit.id,
        'poiId': selection.poi.id,
        'name': selection.poi.name,
        'countryName': selection.country.name,
        'eventName': selection.event.name,
        'circuitName': selection.circuit.name,
      };
      _statusError = null;
      _hydratedRemoteKey = null;
    });
  }

  Future<void> _publishLiveStatus() async {
    if (!_hasPersistedLinkedIds) {
      setState(() => _statusError = 'Liez d\'abord un restaurant.');
      return;
    }

    if (!_selectionMatchesLinked) {
      setState(() {
        _statusError = 'Confirmez d\'abord la nouvelle liaison avant de publier le statut live.';
      });
      return;
    }

    setState(() {
      _publishing = true;
      _statusError = null;
    });

    try {
      await _service.setRestaurantLiveTableStatus(
        countryId: _countryId,
        eventId: _eventId,
        circuitId: _circuitId,
        poiId: _poiId,
        enabled: _liveEnabled,
        status: _liveStatus,
        availableTables: _parseInt(_availableCtrl.text),
        capacity: _parseInt(_capacityCtrl.text),
        message: _messageCtrl.text,
      );
      if (!mounted) return;
      TopSnackBar.show(
        context,
        const SnackBar(content: Text('Statut live publié.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusError = e.toString());
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _hydrateFromRemote(LiveTableState state) {
    final key = _persistedLinkedKey;
    if (_hydratedRemoteKey == key) return;
    _hydratedRemoteKey = key;
    _liveEnabled = state.enabled;
    _liveStatus = state.status == LiveTableStatus.unknown
        ? LiveTableStatus.available
        : state.status;
    _availableCtrl.text = state.availableTables?.toString() ?? '';
    _capacityCtrl.text = state.capacity?.toString() ?? '';
    _messageCtrl.text = state.message ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final businessName = (widget.businessData['companyName'] ?? 'Entreprise')
        .toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restaurant et live tables',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rattachez votre restaurant Food a $businessName puis publiez votre statut de tables en direct.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              _hasBusinessLiveSubscription
                  ? 'Votre abonnement business live tables est actif.'
                  : 'Activez un abonnement eligible pour modifier et publier vos tables en direct.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _hasBusinessLiveSubscription
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickRestaurant,
              icon: const Icon(Icons.storefront_outlined),
              label: Text(
                _hasPersistedLinkedIds ? 'Changer de restaurant' : 'Choisir mon restaurant',
              ),
            ),
            if (_hasLinkedIds) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _restaurantName.isEmpty ? 'Restaurant sélectionné' : _restaurantName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        (_selectedRestaurantRef['countryName'] ?? _countryId).toString(),
                        (_selectedRestaurantRef['eventName'] ?? _eventId).toString(),
                        (_selectedRestaurantRef['circuitName'] ?? _circuitId).toString(),
                      ].where((e) => e.trim().isNotEmpty).join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'POI: $_poiId',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_hasPersistedLinkedIds && !_selectionMatchesLinked) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Cette sélection n\'est pas encore liée. Cliquez sur le bouton ci-dessous pour remplacer la liaison actuelle.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else if (_hasPersistedLinkedIds) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Restaurant actuellement lié à votre compte professionnel.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_hasPersistedLinkedIds || !_selectionMatchesLinked) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _linking ? null : _assignRestaurantPoi,
                    icon: const Icon(Icons.link_rounded),
                    label: Text(
                      _linking
                          ? 'Liaison…'
                          : _hasPersistedLinkedIds
                              ? 'Remplacer la liaison'
                              : 'Lier ce restaurant',
                    ),
                  ),
                ),
              ],
            ],
            if (_statusError != null) ...[
              const SizedBox(height: 10),
              Text(
                _statusError!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
            if (_hasPersistedLinkedIds) ...[
              const SizedBox(height: 16),
              StreamBuilder<LiveTableState>(
                stream: _repository.watchStatus(
                  countryId: _linkedCountryId,
                  eventId: _linkedEventId,
                  circuitId: _linkedCircuitId,
                  poiId: _linkedPoiId,
                ),
                builder: (context, snap) {
                  final remoteState = snap.data;
                  final isRemoteLoading =
                      snap.connectionState == ConnectionState.waiting && !snap.hasData;
                  if (remoteState != null) {
                    _hydrateFromRemote(remoteState);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Etat public actuel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (isRemoteLoading) ...[
                        Row(
                          children: const [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text('Chargement du statut actuel...'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ] else if (remoteState != null && remoteState.enabled) ...[
                        LiveTableStatusBadge(
                          status: remoteState.status,
                          isFresh: remoteState.isFresh,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          remoteState.message ?? 'Le statut live est actuellement visible sur la fiche publique.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Text(
                          'Aucun statut live publie pour le moment. Vous pouvez preparer la premiere mise a jour ci-dessous.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                      ],
                      ValueListenableBuilder<bool>(
                        valueListenable: PremiumService.instance.isPremium,
                        builder: (context, isPremium, _) {
                          final hasLiveTableAccess =
                              isPremium || _hasBusinessLiveSubscription;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LiveTableProPanel(
                                layerType: 'food',
                                isPremium: isPremium,
                                isBusinessSubscribed: _hasBusinessLiveSubscription,
                                isLoadingRemoteState: isRemoteLoading,
                                enabled: _liveEnabled,
                                status: _liveStatus,
                                availableCtrl: _availableCtrl,
                                capacityCtrl: _capacityCtrl,
                                messageCtrl: _messageCtrl,
                                onToggleEnabled: (v) {
                                  setState(() => _liveEnabled = v);
                                },
                                onStatusChanged: (v) {
                                  setState(() => _liveStatus = v);
                                },
                                onOpenPaywall: () {
                                  Navigator.of(context).pushNamed('/paywall');
                                },
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  onPressed: (_publishing ||
                                          !_selectionMatchesLinked ||
                                          isRemoteLoading ||
                                          !hasLiveTableAccess)
                                      ? null
                                      : _publishLiveStatus,
                                  icon: const Icon(Icons.publish_rounded),
                                  label: Text(
                                    _publishing
                                        ? 'Publication…'
                                        : 'Publier le statut live',
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
