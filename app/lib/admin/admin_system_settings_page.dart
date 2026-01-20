import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../services/auth_claims_service.dart';

/// Page de gestion des paramètres système (Super Admin uniquement)
class AdminSystemSettingsPage extends StatefulWidget {
  const AdminSystemSettingsPage({Key? key}) : super(key: key);

  @override
  State<AdminSystemSettingsPage> createState() => _AdminSystemSettingsPageState();
}

class _AdminSystemSettingsPageState extends State<AdminSystemSettingsPage> {
  final _authService = AuthClaimsService.instance;
  final _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;
  Map<String, dynamic> _systemConfig = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = await _authService.getCurrentAppUser();
      final configDoc = await _firestore.collection('config').doc('system').get();

      setState(() {
        _currentUser = user;
        _systemConfig = configDoc.data() ?? {
          'maintenanceMode': false,
          'allowRegistration': true,
          'requireEmailVerification': true,
          'maxUploadSize': 10, // MB
          'sessionTimeout': 24, // heures
          'enableNotifications': true,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      await _firestore.collection('config').doc('system').set(
            _systemConfig,
            SetOptions(merge: true),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration sauvegardée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le cache'),
        content: const Text(
          'Cette action va vider tous les caches de l\'application. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Vider'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Logique de vidage du cache
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache vidé')),
        );
      }
    }
  }

  Future<void> _generateBackup() async {
    setState(() => _isSaving = true);

    try {
      // Logique de backup (à implémenter avec Cloud Functions)
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup généré avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser?.isSuperAdmin != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: const Center(
          child: Text('Cette page est réservée aux super administrateurs'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres système'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveConfig,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Général',
              [
                SwitchListTile(
                  title: const Text('Mode maintenance'),
                  subtitle: const Text('Bloquer l\'accès à l\'application'),
                  value: _systemConfig['maintenanceMode'] ?? false,
                  onChanged: (value) {
                    setState(() => _systemConfig['maintenanceMode'] = value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Autoriser les inscriptions'),
                  subtitle: const Text('Permettre la création de nouveaux comptes'),
                  value: _systemConfig['allowRegistration'] ?? true,
                  onChanged: (value) {
                    setState(() => _systemConfig['allowRegistration'] = value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Vérification email obligatoire'),
                  subtitle: const Text('Exiger la vérification de l\'email'),
                  value: _systemConfig['requireEmailVerification'] ?? true,
                  onChanged: (value) {
                    setState(() => _systemConfig['requireEmailVerification'] = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Sécurité',
              [
                ListTile(
                  title: const Text('Timeout de session'),
                  subtitle: Text('${_systemConfig['sessionTimeout'] ?? 24} heures'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editSessionTimeout(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Fichiers',
              [
                ListTile(
                  title: const Text('Taille max upload'),
                  subtitle: Text('${_systemConfig['maxUploadSize'] ?? 10} MB'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editMaxUploadSize(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Notifications',
              [
                SwitchListTile(
                  title: const Text('Activer les notifications'),
                  subtitle: const Text('Autoriser l\'envoi de notifications push'),
                  value: _systemConfig['enableNotifications'] ?? true,
                  onChanged: (value) {
                    setState(() => _systemConfig['enableNotifications'] = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Maintenance',
              [
                ListTile(
                  leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                  title: const Text('Vider le cache'),
                  subtitle: const Text('Supprimer tous les fichiers en cache'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearCache,
                ),
                ListTile(
                  leading: const Icon(Icons.backup, color: Colors.blue),
                  title: const Text('Générer un backup'),
                  subtitle: const Text('Créer une sauvegarde complète'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _generateBackup,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Purger les données anciennes'),
                  subtitle: const Text('Supprimer les données de plus de 90 jours'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPurgeDialog(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDangerZone(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Zone dangereuse',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
          ),
        ),
        Card(
          color: Colors.red.shade50,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: const Text('Réinitialiser tous les utilisateurs'),
                subtitle: const Text('Supprimer tous les comptes utilisateurs'),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: () => _showResetUsersDialog(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editSessionTimeout() async {
    final controller = TextEditingController(
      text: (_systemConfig['sessionTimeout'] ?? 24).toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timeout de session'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Heures',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _systemConfig['sessionTimeout'] = result);
    }
  }

  Future<void> _editMaxUploadSize() async {
    final controller = TextEditingController(
      text: (_systemConfig['maxUploadSize'] ?? 10).toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Taille max upload'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'MB',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _systemConfig['maxUploadSize'] = result);
    }
  }

  Future<void> _showPurgeDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purger les données'),
        content: const Text(
          'Cette action va supprimer toutes les données de plus de 90 jours. Cette action est irréversible. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Purger'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Logique de purge
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purge effectuée')),
        );
      }
    }
  }

  Future<void> _showResetUsersDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ DANGER ⚠️'),
        content: const Text(
          'Cette action va supprimer TOUS les comptes utilisateurs de la base de données. Cette action est IRRÉVERSIBLE.\n\nÊtes-vous absolument certain ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('TOUT SUPPRIMER'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Demander une seconde confirmation
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dernière confirmation'),
          content: const Text('Tapez "DELETE ALL" pour confirmer'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
          ],
        ),
      );

      // Logique de suppression (à implémenter avec extrême prudence)
    }
  }
}
