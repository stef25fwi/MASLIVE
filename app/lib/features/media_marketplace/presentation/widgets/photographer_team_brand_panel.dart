import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/photographer_profile_model.dart';
import '../../data/repositories/photographer_complete_flow_repository.dart';

class PhotographerTeamBrandPanel extends StatefulWidget {
  const PhotographerTeamBrandPanel({
    super.key,
    required this.profile,
    required this.repository,
  });

  final PhotographerProfileModel profile;
  final PhotographerCompleteFlowRepository repository;

  @override
  State<PhotographerTeamBrandPanel> createState() =>
      _PhotographerTeamBrandPanelState();
}

class _PhotographerTeamBrandPanelState
    extends State<PhotographerTeamBrandPanel> {
  final TextEditingController _headline = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _accent = TextEditingController();
  final TextEditingController _watermark = TextEditingController();
  final List<Map<String, dynamic>> _collaborators = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _brands = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _promotions = <Map<String, dynamic>>[];
  Map<String, dynamic> _limits = const <String, dynamic>{};
  String _layout = 'grid';
  bool _showName = true;
  bool _showEvent = true;
  bool _faceConsent = false;
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  String? _latestApiKeyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _headline.dispose();
    _description.dispose();
    _accent.dispose();
    _watermark.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.loadWorkspaceConfig(
        widget.profile.photographerId,
      );
      final config = result['config'] is Map
          ? Map<String, dynamic>.from(result['config'] as Map)
          : <String, dynamic>{};
      final storefront = config['storefront'] is Map
          ? Map<String, dynamic>.from(config['storefront'] as Map)
          : <String, dynamic>{};
      _limits = result['limits'] is Map
          ? Map<String, dynamic>.from(result['limits'] as Map)
          : const <String, dynamic>{};
      _collaborators
        ..clear()
        ..addAll(_maps(config['collaborators']));
      _brands
        ..clear()
        ..addAll(_maps(config['brands']));
      _promotions
        ..clear()
        ..addAll(_maps(config['promotions']));
      _headline.text = storefront['headline']?.toString() ?? '';
      _description.text = storefront['description']?.toString() ?? '';
      _accent.text = storefront['accentColor']?.toString() ?? '';
      _watermark.text = storefront['customWatermarkText']?.toString() ?? '';
      _layout = storefront['layout']?.toString() ?? 'grid';
      _showName = storefront['showPhotographerName'] as bool? ?? true;
      _showEvent = storefront['showEventContext'] as bool? ?? true;
      _faceConsent = config['faceGroupingConsent'] as bool? ?? false;
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! Iterable) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.saveWorkspaceConfig(
        photographerId: widget.profile.photographerId,
        config: <String, dynamic>{
          'collaborators': _collaborators,
          'brands': _brands,
          'promotions': _promotions,
          'faceGroupingConsent': _faceConsent,
          'storefront': <String, dynamic>{
            'headline': _headline.text.trim(),
            'description': _description.text.trim(),
            'accentColor': _accent.text.trim(),
            'layout': _layout,
            'showPhotographerName': _showName,
            'showEventContext': _showEvent,
            'customWatermarkText': _watermark.text.trim(),
          },
        },
      );
      _message('Équipe, marques et boutique enregistrées.');
      await _load();
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCollaborator({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final email = TextEditingController(text: existing?['email']?.toString() ?? '');
    var role = existing?['role']?.toString() ?? 'editor';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(existing == null ? 'Inviter un collaborateur' : 'Modifier le collaborateur'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'E-mail')),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'viewer', child: Text('Lecture')),
                    DropdownMenuItem(value: 'editor', child: Text('Photos et galeries')),
                    DropdownMenuItem(value: 'manager', child: Text('Gestionnaire')),
                    DropdownMenuItem(value: 'finance', child: Text('Finances')),
                  ],
                  onChanged: (value) => update(() => role = value ?? 'editor'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        final value = <String, dynamic>{
          'id': existing?['id']?.toString(),
          'name': name.text.trim(),
          'email': email.text.trim(),
          'role': role,
          'status': existing?['status']?.toString() ?? 'invited',
        };
        if (existing == null) {
          _collaborators.add(value);
        } else {
          final index = _collaborators.indexOf(existing);
          if (index >= 0) _collaborators[index] = value;
        }
      });
    }
    name.dispose();
    email.dispose();
  }

  Future<void> _addBrand({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final logo = TextEditingController(text: existing?['logoUrl']?.toString() ?? '');
    final domain = TextEditingController(text: existing?['domain']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    final color = TextEditingController(text: existing?['accentColor']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Ajouter une marque' : 'Modifier la marque'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom de marque')),
                TextField(controller: logo, decoration: const InputDecoration(labelText: 'URL du logo')),
                TextField(controller: domain, decoration: const InputDecoration(labelText: 'Domaine ou sous-boutique')),
                TextField(controller: color, decoration: const InputDecoration(labelText: 'Couleur principale (#RRGGBB)')),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (saved == true) {
      setState(() {
        final value = <String, dynamic>{
          'id': existing?['id']?.toString(),
          'name': name.text.trim(),
          'logoUrl': logo.text.trim(),
          'domain': domain.text.trim(),
          'accentColor': color.text.trim(),
          'description': description.text.trim(),
        };
        if (existing == null) {
          _brands.add(value);
        } else {
          final index = _brands.indexOf(existing);
          if (index >= 0) _brands[index] = value;
        }
      });
    }
    for (final controller in <TextEditingController>[name, logo, domain, description, color]) {
      controller.dispose();
    }
  }

  Future<void> _addPromotion({Map<String, dynamic>? existing}) async {
    final code = TextEditingController(text: existing?['code']?.toString() ?? '');
    final percent = TextEditingController(text: existing?['percentOff']?.toString() ?? '10');
    final amount = TextEditingController(text: existing?['amountOff']?.toString() ?? '0');
    final galleries = TextEditingController(
      text: (existing?['galleryIds'] as Iterable? ?? const <dynamic>[]).join(', '),
    );
    var active = existing?['active'] as bool? ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(existing == null ? 'Créer un code promotionnel' : 'Modifier le code'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
                TextField(controller: percent, decoration: const InputDecoration(labelText: 'Réduction (%)')),
                TextField(controller: amount, decoration: const InputDecoration(labelText: 'Réduction fixe (€)')),
                TextField(
                  controller: galleries,
                  decoration: const InputDecoration(labelText: 'Galeries ciblées (facultatif)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  title: const Text('Code actif'),
                  onChanged: (value) => update(() => active = value),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        final value = <String, dynamic>{
          'id': existing?['id']?.toString(),
          'code': code.text.trim().toUpperCase(),
          'percentOff': double.tryParse(percent.text.replaceAll(',', '.')) ?? 0,
          'amountOff': double.tryParse(amount.text.replaceAll(',', '.')) ?? 0,
          'active': active,
          'galleryIds': galleries.text
              .split(RegExp(r'[,;\n]+'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
        };
        if (existing == null) {
          _promotions.add(value);
        } else {
          final index = _promotions.indexOf(existing);
          if (index >= 0) _promotions[index] = value;
        }
      });
    }
    for (final controller in <TextEditingController>[code, percent, amount, galleries]) {
      controller.dispose();
    }
  }

  Future<void> _createApiKey() async {
    final label = TextEditingController(text: 'Import studio');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer une clé d’import API'),
        content: TextField(controller: label, decoration: const InputDecoration(labelText: 'Nom de la clé')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Créer')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final result = await widget.repository.createApiKey(
          photographerId: widget.profile.photographerId,
          label: label.text.trim(),
        );
        final apiKey = result['apiKey']?.toString() ?? '';
        final endpoint = result['endpoint']?.toString() ?? '';
        _latestApiKeyId = result['keyId']?.toString();
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clé créée — copie unique'),
            content: SizedBox(
              width: 620,
              child: SelectableText(
                'Clé : $apiKey\n\nEndpoint : $endpoint\n\nActions POST : prepare puis finalize. La clé complète ne sera plus réaffichée.',
              ),
            ),
            actions: <Widget>[
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: 'API_KEY=$apiKey\nENDPOINT=$endpoint'),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copier'),
              ),
            ],
          ),
        );
      } catch (error) {
        _message(error.toString(), error: true);
      }
    }
    label.dispose();
  }

  Future<void> _revokeLatestKey() async {
    final keyId = _latestApiKeyId;
    if (keyId == null) return;
    try {
      await widget.repository.revokeApiKey(
        photographerId: widget.profile.photographerId,
        keyId: keyId,
      );
      setState(() => _latestApiKeyId = null);
      _message('Clé API révoquée.');
    } catch (error) {
      _message(error.toString(), error: true);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('Réessayer : $_error'),
        ),
      );
    }
    final collaboratorLimit = (_limits['collaborators'] as num?)?.toInt() ?? 0;
    final brandLimit = (_limits['brands'] as num?)?.toInt() ?? 1;
    final promotionLimit = (_limits['promotions'] as num?)?.toInt() ?? 0;
    final apiEnabled = _limits['api'] as bool? ?? false;
    final customWatermark = _limits['customWatermark'] as bool? ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Personnalisation de la boutique',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                TextField(controller: _headline, decoration: const InputDecoration(labelText: 'Accroche')),
                TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Présentation')),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(width: 240, child: TextField(controller: _accent, decoration: const InputDecoration(labelText: 'Couleur #RRGGBB'))),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        initialValue: _layout,
                        decoration: const InputDecoration(labelText: 'Mise en page'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'grid', child: Text('Grille')),
                          DropdownMenuItem(value: 'editorial', child: Text('Éditoriale')),
                          DropdownMenuItem(value: 'minimal', child: Text('Minimaliste')),
                        ],
                        onChanged: (value) => setState(() => _layout = value ?? 'grid'),
                      ),
                    ),
                    if (customWatermark)
                      SizedBox(width: 300, child: TextField(controller: _watermark, decoration: const InputDecoration(labelText: 'Filigrane personnalisé'))),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showName,
                  title: const Text('Afficher le nom du photographe'),
                  onChanged: (value) => setState(() => _showName = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showEvent,
                  title: const Text('Afficher le contexte événement et circuit'),
                  onChanged: (value) => setState(() => _showEvent = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _faceConsent,
                  title: const Text('Consentement au regroupement visuel anonyme'),
                  subtitle: const Text(
                    'Aucun nom n’est associé. Les signatures anonymes servent uniquement à retrouver les photos d’une même personne et suivent la durée de conservation des photos.',
                  ),
                  onChanged: (value) => setState(() => _faceConsent = value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Collaborateurs (${_collaborators.length}/$collaboratorLimit)',
          action: FilledButton.tonalIcon(
            onPressed: _collaborators.length >= collaboratorLimit ? null : _addCollaborator,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Inviter'),
          ),
          children: _collaborators.isEmpty
              ? const <Widget>[ListTile(title: Text('Aucun collaborateur'))]
              : _collaborators
                  .map(
                    (person) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(person['name']?.toString() ?? person['email']?.toString() ?? ''),
                      subtitle: Text('${person['email'] ?? ''} • ${person['role'] ?? 'editor'} • ${person['status'] ?? 'invited'}'),
                      onTap: () => _addCollaborator(existing: person),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() => _collaborators.remove(person)),
                      ),
                    ),
                  )
                  .toList(growable: false),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Marques et boutiques (${_brands.length}/$brandLimit)',
          action: FilledButton.tonalIcon(
            onPressed: _brands.length >= brandLimit ? null : _addBrand,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Ajouter'),
          ),
          children: _brands.isEmpty
              ? const <Widget>[ListTile(title: Text('La marque principale utilise le profil photographe.'))]
              : _brands
                  .map(
                    (brand) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
                      title: Text(brand['name']?.toString() ?? ''),
                      subtitle: Text('${brand['domain'] ?? ''} • ${brand['accentColor'] ?? ''}'),
                      onTap: () => _addBrand(existing: brand),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _brands.remove(brand)),
                      ),
                    ),
                  )
                  .toList(growable: false),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Codes promotionnels (${_promotions.length}/$promotionLimit)',
          action: FilledButton.tonalIcon(
            onPressed: _promotions.length >= promotionLimit ? null : _addPromotion,
            icon: const Icon(Icons.local_offer_outlined),
            label: const Text('Créer'),
          ),
          children: _promotions.isEmpty
              ? const <Widget>[ListTile(title: Text('Aucun code promotionnel actif.'))]
              : _promotions
                  .map(
                    (promotion) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.percent)),
                      title: Text(promotion['code']?.toString() ?? ''),
                      subtitle: Text(
                        '${promotion['percentOff'] ?? 0}% • ${promotion['amountOff'] ?? 0} € • ${promotion['active'] == true ? 'actif' : 'inactif'}',
                      ),
                      onTap: () => _addPromotion(existing: promotion),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _promotions.remove(promotion)),
                      ),
                    ),
                  )
                  .toList(growable: false),
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(Icons.api_outlined),
            title: const Text('Import automatisé par API'),
            subtitle: Text(
              apiEnabled
                  ? 'Crée une clé pour envoyer des images depuis un logiciel de studio, un NAS ou un serveur.'
                  : 'Disponible avec les formules Studio et Agence.',
            ),
            trailing: Wrap(
              spacing: 6,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: apiEnabled ? _createApiKey : null,
                  child: const Text('Créer une clé'),
                ),
                if (_latestApiKeyId != null)
                  OutlinedButton(
                    onPressed: _revokeLatestKey,
                    child: const Text('Révoquer'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Enregistrement…' : 'Enregistrer tout le studio'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.action,
    required this.children,
  });

  final String title;
  final Widget action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                action,
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}
