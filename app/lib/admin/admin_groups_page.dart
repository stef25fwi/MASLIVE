import 'package:flutter/material.dart';

import '../models/group_admin.dart';
import '../models/group_tracker.dart';
import '../services/group/group_link_service.dart';
import '../ui/snack/top_snack_bar.dart';

class AdminGroupsPage extends StatefulWidget {
  const AdminGroupsPage({super.key});

  @override
  State<AdminGroupsPage> createState() => _AdminGroupsPageState();
}

class _AdminGroupsPageState extends State<AdminGroupsPage> {
  final _linkService = GroupLinkService.instance;

  Future<void> _addTrackerToAdmin(GroupAdmin admin) async {
    final controller = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ajouter un tracker'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saisissez l\'UID du compte tracker (document Firestore).',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Tracker UID',
                  prefixIcon: Icon(Icons.badge),
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (confirmed != true) return;

      final trackerUid = controller.text.trim();
      if (trackerUid.isEmpty) {
        TopSnackBar.show(
          context,
          const SnackBar(
            content: Text('UID tracker requis'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        await _linkService.linkExistingTrackerToAdmin(
          trackerUid: trackerUid,
          adminGroupId: admin.adminGroupId,
          linkedAdminUid: admin.uid,
        );

        if (!mounted) return;
        TopSnackBar.show(
          context,
          const SnackBar(
            content: Text('Tracker ajouté au groupe'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        TopSnackBar.show(
          context,
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmUnlinkTracker({
    required GroupAdmin admin,
    required GroupTracker tracker,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce tracker ?'),
        content: Text(
          'Confirmer la suppression du tracker "${tracker.displayName}"\n(UID: ${tracker.uid})\ndu groupe ${admin.adminGroupId}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _linkService.unlinkTrackerByUid(trackerUid: tracker.uid);

      if (!mounted) return;
      TopSnackBar.show(
        context,
        const SnackBar(
          content: Text('Tracker supprimé du groupe'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Groupes'),
      ),
      body: StreamBuilder<List<GroupAdmin>>(
        stream: _linkService.streamAllAdmins(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erreur: ${snapshot.error}'),
              ),
            );
          }

          final admins = snapshot.data ?? const <GroupAdmin>[];
          if (admins.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun groupe admin.'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: admins.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final admin = admins[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.group, color: Colors.purple),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  admin.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Code: ${admin.adminGroupId}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Admin UID: ${admin.uid}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _addTrackerToAdmin(admin),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      StreamBuilder<List<GroupTracker>>(
                        stream: _linkService.streamAdminTrackers(admin.adminGroupId),
                        builder: (context, trackerSnap) {
                          final trackers = trackerSnap.data ?? const <GroupTracker>[];

                          if (trackerSnap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trackers rattachés: ${trackers.length}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (trackers.isEmpty)
                                Text(
                                  'Aucun tracker rattaché.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                )
                              else
                                ...trackers.map(
                                  (t) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.person_pin_circle),
                                    title: Text(t.displayName.isEmpty ? 'Sans nom' : t.displayName),
                                    subtitle: Text('UID: ${t.uid}'),
                                    trailing: IconButton(
                                      tooltip: 'Supprimer',
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _confirmUnlinkTracker(
                                        admin: admin,
                                        tracker: t,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
