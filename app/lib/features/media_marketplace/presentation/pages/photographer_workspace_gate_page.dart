import 'package:flutter/material.dart';

import '../../data/repositories/photographer_repository.dart';
import 'photographer_complete_flow_page.dart';

class PhotographerWorkspaceGatePage extends StatefulWidget {
  const PhotographerWorkspaceGatePage({
    super.key,
    this.initialSection = 0,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
  });

  final int initialSection;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;

  @override
  State<PhotographerWorkspaceGatePage> createState() =>
      _PhotographerWorkspaceGatePageState();
}

class _PhotographerWorkspaceGatePageState
    extends State<PhotographerWorkspaceGatePage> {
  final PhotographerRepository _repository = PhotographerRepository();
  List<PhotographerWorkspaceAccess> _workspaces =
      const <PhotographerWorkspaceAccess>[];
  PhotographerWorkspaceAccess? _selected;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workspaces = await _repository.getAccessibleWorkspaces();
      final selectedId = await _repository.selectedWorkspaceId();
      final selected = workspaces.where(
        (workspace) => workspace.photographerId == selectedId,
      );
      final resolved = selected.isNotEmpty
          ? selected.first
          : (workspaces.isEmpty ? null : workspaces.first);
      if (resolved != null) {
        await _repository.selectWorkspace(resolved.photographerId);
      }
      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _selected = resolved;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(PhotographerWorkspaceAccess workspace) async {
    await _repository.selectWorkspace(workspace.photographerId);
    if (!mounted) return;
    setState(() => _selected = workspace);
  }

  Future<void> _chooseWorkspace() async {
    final current = _selected;
    var selectedId = current?.photographerId;
    final selected = await showDialog<PhotographerWorkspaceAccess>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Choisir un espace photographe'),
          content: SizedBox(
            width: 520,
            child: ListView(
              shrinkWrap: true,
              children: _workspaces.map((workspace) {
                return RadioListTile<String>(
                  value: workspace.photographerId,
                  groupValue: selectedId,
                  onChanged: (value) => update(() => selectedId = value),
                  title: Text(workspace.profile.brandName),
                  subtitle: Text(
                    '${workspace.role} • ${workspace.profile.city ?? ''} ${workspace.profile.country ?? ''}',
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        _workspaces.firstWhere(
                          (workspace) =>
                              workspace.photographerId == selectedId,
                        ),
                      ),
              child: const Text('Ouvrir'),
            ),
          ],
        ),
      ),
    );
    if (selected != null) await _select(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(_error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final selected = _selected;
    if (selected == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Centre photographe MASLIVE')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aucun profil photographe ni invitation active. Crée un profil ou demande une invitation à un propriétaire Studio/Agence.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        PhotographerCompleteFlowPage(
          key: ValueKey<String>(selected.photographerId),
          initialSection: widget.initialSection,
          eventId: widget.eventId,
          eventName: widget.eventName,
          circuitId: widget.circuitId,
          circuitName: widget.circuitName,
        ),
        if (_workspaces.length > 1)
          Positioned(
            top: 8,
            right: 64,
            child: SafeArea(
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(22),
                child: TextButton.icon(
                  onPressed: _chooseWorkspace,
                  icon: const Icon(Icons.switch_account_outlined),
                  label: Text(
                    '${selected.profile.brandName} • ${selected.role}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
