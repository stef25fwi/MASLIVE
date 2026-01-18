import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _q = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _placesStream() {
    return FirebaseFirestore.instance
        .collection('places')
        .where('active', isEqualTo: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un lieu…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _placesStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                final filtered = docs.where((d) {
                  if (_q.isEmpty) return true;
                  final data = d.data();
                  final name = (data['name'] ?? '') as String;
                  final type = (data['type'] ?? '') as String;
                  return name.toLowerCase().contains(_q) || type.toLowerCase().contains(_q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Aucun résultat'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 18),
                  itemBuilder: (context, i) {
                    final data = filtered[i].data();
                    final name = (data['name'] ?? 'Lieu') as String;
                    final type = (data['type'] ?? '-') as String;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(type),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(name),
                            content: Text('Type: $type'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
