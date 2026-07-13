import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/superadmin_user_management_service.dart';
import 'admin_gate.dart';

class SuperAdminUserManagementPage extends StatefulWidget {
  const SuperAdminUserManagementPage({
    super.key,
    this.initialRole,
  });

  final String? initialRole;

  @override
  State<SuperAdminUserManagementPage> createState() =>
      _SuperAdminUserManagementPageState();
}

class _SuperAdminUserManagementPageState
    extends State<SuperAdminUserManagementPage> {
  final _service = SuperAdminUserManagementService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<ManagedUserAccount> _users = const <ManagedUserAccount>[];
  bool _loading = true;
  bool _truncated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadUsers());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadUsers);
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _service.searchUsers(_searchController.text);
      if (!mounted) return;
      final initialRole = widget.initialRole;
      setState(() {
        _users = initialRole == null
            ? result.users
            : result.users.where((user) => user.role == initialRole).toList();
        _truncated = result.truncated;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      requireSuperAdmin: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialRole == 'group'
                ? 'Admin Groupe & Trackers'
                : 'Gestion des utilisateurs',
          ),
          actions: [
            IconButton(
              onPressed: _loading ? null : _loadUsers,
              tooltip: 'Rafraîchir',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAccountForm(
            initialRole: widget.initialRole == 'group' ? 'group' : 'user',
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Créer'),
        ),
        body: Column(
          children: [
            _buildActionsHeader(),
            _buildSearchBar(),
            if (_truncated)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'La recherche est limitée aux 1 000 premiers comptes Firebase Auth.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsHeader() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: () => _showAccountForm(initialRole: 'group'),
            icon: const Icon(Icons.groups_2_rounded),
            label: const Text('Créer Admin Groupe'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => _showAccountForm(initialRole: 'tracker'),
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Créer Tracker'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _showAccountForm(initialRole: 'user'),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Autre compte'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Nom, email, UID, rôle ou code groupe',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () => _searchController.clear(),
                  icon: const Icon(Icons.close_rounded),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadUsers, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur trouvé.'));
    }
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildUserCard(_users[index]),
      ),
    );
  }

  Widget _buildUserCard(ManagedUserAccount user) {
    final roleLabel = _roleLabel(user.role);
    final roleColor = _roleColor(user.role);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  child: Icon(_roleIcon(user.role), color: roleColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName.isEmpty ? 'Sans nom' : user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        user.email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(roleLabel),
                  side: BorderSide(color: roleColor.withValues(alpha: 0.35)),
                  backgroundColor: roleColor.withValues(alpha: 0.08),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _infoChip(
                  user.isActive ? 'Actif' : 'Désactivé',
                  user.isActive ? Icons.check_circle : Icons.block,
                ),
                if (user.adminGroupId != null)
                  _infoChip('Code ${user.adminGroupId}', Icons.qr_code_2_rounded),
                _infoChip(
                  user.emailVerified ? 'Email vérifié' : 'Email non vérifié',
                  Icons.mark_email_read_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              'UID : ${user.uid}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (user.adminGroupId != null)
                  IconButton(
                    tooltip: 'Afficher QR et code',
                    onPressed: () => _showQrDialog(
                      displayName: user.displayName,
                      email: user.email,
                      code: user.adminGroupId!,
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded),
                  ),
                if (user.isGroupAdmin)
                  IconButton(
                    tooltip: 'Régénérer le code groupe',
                    onPressed: () => _regenerateGroupCode(user),
                    icon: const Icon(Icons.autorenew_rounded),
                  ),
                IconButton(
                  tooltip: 'Modifier',
                  onPressed: () => _showAccountForm(user: user),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: user.role == 'superAdmin'
                      ? null
                      : () => _confirmDelete(user),
                  color: Colors.red,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _showAccountForm({
    ManagedUserAccount? user,
    String initialRole = 'user',
  }) async {
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    final groupController = TextEditingController(text: user?.adminGroupId ?? '');
    var role = user?.role ?? initialRole;
    var isActive = user?.isActive ?? true;
    var submitting = false;
    String? formError;

    final result = await showModalBottomSheet<ManagedUserMutationResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            final email = emailController.text.trim();
            final password = passwordController.text;
            final name = nameController.text.trim();
            final groupCode = groupController.text.trim();
            if (name.isEmpty || !email.contains('@')) {
              setSheetState(() => formError = 'Nom et email valides requis.');
              return;
            }
            if (user == null && password.length < 12) {
              setSheetState(
                () => formError = 'Mot de passe de 12 caractères minimum requis.',
              );
              return;
            }
            if (role == 'tracker' && !RegExp(r'^\d{6}$').hasMatch(groupCode)) {
              setSheetState(
                () => formError = 'Code Admin Groupe à 6 chiffres requis.',
              );
              return;
            }
            setSheetState(() {
              submitting = true;
              formError = null;
            });
            try {
              final mutation = user == null
                  ? await _service.createUser(
                      email: email,
                      password: password,
                      displayName: name,
                      role: role,
                      adminGroupId: groupCode.isEmpty ? null : groupCode,
                    )
                  : await _service.updateUser(
                      uid: user.uid,
                      email: email,
                      displayName: name,
                      role: role,
                      isActive: isActive,
                      password: password.isEmpty ? null : password,
                      adminGroupId: groupCode.isEmpty ? null : groupCode,
                    );
              if (sheetContext.mounted) Navigator.of(sheetContext).pop(mutation);
            } catch (error) {
              setSheetState(() {
                submitting = false;
                formError = error.toString();
              });
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                4,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user == null ? 'Créer un compte' : 'Modifier le compte',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom affiché',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: user == null
                            ? 'Mot de passe temporaire'
                            : 'Nouveau mot de passe (optionnel)',
                        helperText: '12 caractères minimum',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: role == 'superAdmin' ? 'user' : role,
                      decoration: const InputDecoration(
                        labelText: 'Profil',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('Utilisateur')),
                        DropdownMenuItem(value: 'tracker', child: Text('Tracker Groupe')),
                        DropdownMenuItem(value: 'group', child: Text('Admin Groupe')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin MASLIVE')),
                      ],
                      onChanged: user?.role == 'superAdmin'
                          ? null
                          : (value) => setSheetState(() => role = value ?? 'user'),
                    ),
                    if (role == 'tracker') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: groupController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Code Admin Groupe',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (role == 'group') ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Un code groupe unique et son QR code seront générés automatiquement.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                    if (user != null && user.role != 'superAdmin') ...[
                      const SizedBox(height: 6),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Compte actif'),
                        subtitle: const Text(
                          'Un compte désactivé ne peut plus se connecter.',
                        ),
                        value: isActive,
                        onChanged: (value) =>
                            setSheetState(() => isActive = value),
                      ),
                    ],
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : submit,
                        icon: submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          submitting
                              ? 'Enregistrement...'
                              : user == null
                                  ? 'Créer le compte'
                                  : 'Enregistrer',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    groupController.dispose();

    if (result == null || !mounted) return;
    await _loadUsers();
    if (!mounted) return;
    if (result.adminGroupId != null) {
      await _showQrDialog(
        displayName: result.displayName ?? user?.displayName ?? '',
        email: result.email ?? user?.email ?? '',
        code: result.adminGroupId!,
        qrPayload: result.qrPayload,
      );
    } else {
      _showMessage('Compte enregistré avec succès.');
    }
  }

  Future<void> _regenerateGroupCode(ManagedUserAccount user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Régénérer le code groupe ?'),
        content: const Text(
          'L’ancien QR code cessera de fonctionner. Tous les Trackers déjà rattachés seront migrés vers le nouveau code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Régénérer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await _service.regenerateGroupCode(user.uid);
      await _loadUsers();
      if (!mounted || result.adminGroupId == null) return;
      await _showQrDialog(
        displayName: user.displayName,
        email: user.email,
        code: result.adminGroupId!,
        qrPayload: result.qrPayload,
      );
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _confirmDelete(ManagedUserAccount user) async {
    final confirmationController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${user.displayName}\n${user.email}'),
            const SizedBox(height: 12),
            const Text('Saisissez SUPPRIMER pour confirmer.'),
            const SizedBox(height: 8),
            TextField(
              controller: confirmationController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(
              context,
              confirmationController.text.trim() == 'SUPPRIMER',
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    confirmationController.dispose();
    if (confirmed != true) return;
    try {
      final detached = await _service.deleteUser(user.uid);
      await _loadUsers();
      _showMessage(
        detached > 0
            ? 'Compte supprimé. $detached Tracker(s) ont été détachés.'
            : 'Compte supprimé.',
      );
    } catch (error) {
      _showMessage(error.toString(), error: true);
    }
  }

  Future<void> _showQrDialog({
    required String displayName,
    required String email,
    required String code,
    String? qrPayload,
  }) async {
    final payload = qrPayload ??
        '{"type":"maslive_group","code":"$code","groupName":"$displayName"}';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accès groupe MASLIVE'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: payload, size: 220),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 6),
              Text(displayName, textAlign: TextAlign.center),
              Text(email, textAlign: TextAlign.center),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) Navigator.pop(context);
              _showMessage('Code $code copié.');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copier le code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'superAdmin':
        return 'SuperAdmin';
      case 'admin':
        return 'Admin';
      case 'group':
        return 'Admin Groupe';
      case 'tracker':
        return 'Tracker';
      default:
        return 'Utilisateur';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'superAdmin':
        return Colors.red;
      case 'admin':
        return Colors.blue;
      case 'group':
        return Colors.indigo;
      case 'tracker':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'superAdmin':
        return Icons.security_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'group':
        return Icons.groups_2_rounded;
      case 'tracker':
        return Icons.my_location_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}
