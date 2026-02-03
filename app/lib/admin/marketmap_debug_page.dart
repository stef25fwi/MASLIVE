import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page de debug pour visualiser la structure Firestore
/// marketMap/{country}/events/{event}/circuits/{circuit}.
class MarketMapDebugPage extends StatelessWidget {
  const MarketMapDebugPage({super.key});

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug MarketMap Firestore'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('marketMap').orderBy('name').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final countries = snap.data!.docs;
          if (countries.isEmpty) {
            return const Center(
              child: Text('Aucun pays dans marketMap.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: countries.length,
            itemBuilder: (context, i) {
              final countryDoc = countries[i];
              final countryData = countryDoc.data();
              final countryName = (countryData['name'] ?? countryDoc.id).toString();

              return Card(
                child: ExpansionTile(
                  title: Text('$countryName (${countryDoc.id})'),
                  subtitle: Text('marketMap/${countryDoc.id}'),
                  children: [
                    _EventsList(countryId: countryDoc.id),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  const _EventsList({required this.countryId});

  final String countryId;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('marketMap')
          .doc(countryId)
          .collection('events')
          .orderBy('startDate', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Erreur événements: ${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          );
        }

        final events = snap.data!.docs;
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Aucun événement pour ce pays.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: events.map((eventDoc) {
            final data = eventDoc.data();
            final eventName = (data['name'] ?? eventDoc.id).toString();

            return Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: Card(
                color: Colors.grey.shade50,
                child: ExpansionTile(
                  title: Text('$eventName (${eventDoc.id})',
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    'marketMap/$countryId/events/${eventDoc.id}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    _CircuitsList(
                      countryId: countryId,
                      eventId: eventDoc.id,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CircuitsList extends StatelessWidget {
  const _CircuitsList({required this.countryId, required this.eventId});

  final String countryId;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('marketMap')
          .doc(countryId)
          .collection('events')
          .doc(eventId)
          .collection('circuits')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Erreur circuits: ${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          );
        }

        final circuits = snap.data!.docs;
        if (circuits.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Aucun circuit pour cet événement.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: circuits.map((circuitDoc) {
            final data = circuitDoc.data();
            final circuitName = (data['name'] ?? circuitDoc.id).toString();
            final status = (data['status'] ?? 'draft').toString();
            final isVisible = (data['isVisible'] as bool?) ?? false;

            return ListTile(
              dense: true,
              leading: const Icon(Icons.alt_route, size: 18),
              title: Text(
                '$circuitName (${circuitDoc.id})',
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                'status: $status • visible: ${isVisible ? 'oui' : 'non'}\nmarketMap/$countryId/events/$eventId/circuits/${circuitDoc.id}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Switch(
                value: isVisible,
                onChanged: (v) {
                  circuitDoc.reference.update({'isVisible': v});
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
