// Page historique trajets groupe

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/track_session.dart';
import '../../services/group/group_tracking_service.dart';

class GroupTrackHistoryPage extends StatelessWidget {
  final String adminGroupId;
  final String? uid; // Si null, affiche tous, sinon filtre par utilisateur

  const GroupTrackHistoryPage({
    super.key,
    required this.adminGroupId,
    this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final trackingService = GroupTrackingService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(uid != null ? 'Mon historique' : 'Historique Groupe'),
      ),
      body: StreamBuilder<List<TrackSession>>(
        stream: uid != null
            ? trackingService.streamUserSessions(adminGroupId, uid!)
            : trackingService.streamGroupSessions(adminGroupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 100, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun trajet enregistré',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            );
          }

          final sessions = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: session.isActive ? Colors.green : Colors.grey,
                    child: Icon(
                      session.isActive ? Icons.gps_fixed : Icons.flag,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(session.startedAt),
                  ),
                  subtitle: session.summary != null
                      ? Text(
                          '${session.summary!.distanceKm} km • ${session.summary!.durationFormatted}',
                        )
                      : Text(session.isActive ? 'En cours...' : 'Pas de données'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showSessionDetails(context, session);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSessionDetails(BuildContext context, TrackSession session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails session',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Date', DateFormat('dd/MM/yyyy HH:mm').format(session.startedAt)),
            _buildDetailRow('Utilisateur', session.uid),
            _buildDetailRow('Rôle', session.role),
            if (session.summary != null) ...[
              const Divider(),
              _buildDetailRow('Durée', session.summary!.durationFormatted),
              _buildDetailRow('Distance', '${session.summary!.distanceKm} km'),
              _buildDetailRow('Dénivelé+', '${session.summary!.ascentM.toStringAsFixed(0)} m'),
              _buildDetailRow('Dénivelé-', '${session.summary!.descentM.toStringAsFixed(0)} m'),
              _buildDetailRow('Vitesse moy.', '${session.summary!.avgSpeedKmh} km/h'),
              _buildDetailRow('Points GPS', '${session.summary!.pointsCount}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
