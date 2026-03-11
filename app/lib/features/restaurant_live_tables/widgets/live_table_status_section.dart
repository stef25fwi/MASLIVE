import 'package:flutter/material.dart';

import '../models/live_table_state.dart';
import '../repositories/restaurant_live_table_repository.dart';
import 'live_table_status_badge.dart';

class LiveTableStatusSection extends StatelessWidget {
  const LiveTableStatusSection({
    super.key,
    required this.meta,
    required this.countryId,
    required this.eventId,
    required this.circuitId,
    required this.poiId,
  });

  final Map<String, dynamic>? meta;
  final String? countryId;
  final String? eventId;
  final String? circuitId;
  final String? poiId;

  @override
  Widget build(BuildContext context) {
    final canUseRemote =
        (countryId ?? '').trim().isNotEmpty &&
        (eventId ?? '').trim().isNotEmpty &&
        (circuitId ?? '').trim().isNotEmpty &&
        (poiId ?? '').trim().isNotEmpty;

    if (!canUseRemote) {
      final live = (meta ?? const <String, dynamic>{})['liveTable'];
      if (live is! Map) return const SizedBox.shrink();
      final state = LiveTableState.fromMap(
        Map<String, dynamic>.from(live),
        source: 'metadata',
      );
      if (!state.enabled) return const SizedBox.shrink();
      return _Body(state: state);
    }

    final repo = RestaurantLiveTableRepository();
    return StreamBuilder<LiveTableState>(
      stream: repo.watchStatus(
        countryId: countryId!.trim(),
        eventId: eventId!.trim(),
        circuitId: circuitId!.trim(),
        poiId: poiId!.trim(),
        fallbackMeta: meta,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final state = snap.data!;
        if (!state.enabled) return const SizedBox.shrink();
        return _Body(state: state);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final LiveTableState state;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    String inventory = '';
    if (state.availableTables != null && state.capacity != null && state.capacity! > 0) {
      inventory = '${state.availableTables}/${state.capacity} tables';
    } else if (state.availableTables != null) {
      inventory = '${state.availableTables} tables annoncees';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Disponibilite en direct',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          LiveTableStatusBadge(status: state.status, isFresh: state.isFresh),
          if (inventory.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(inventory, style: small),
          ],
          if ((state.message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(state.message!.trim(), style: small),
          ],
        ],
      ),
    );
  }
}
