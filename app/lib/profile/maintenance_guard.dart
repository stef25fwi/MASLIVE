import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Guard pour vérifier si l'application est en mode maintenance
class MaintenanceGuard extends StatelessWidget {
  final Widget child;
  final Widget? maintenanceFallback;

  const MaintenanceGuard({
    super.key,
    required this.child,
    this.maintenanceFallback,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('maintenance')
          .snapshots(),
      builder: (context, snapshot) {
        // En cas d'erreur, on laisse passer pour ne pas bloquer l'app
        if (snapshot.hasError) {
          return child;
        }

        // Pendant le chargement, on affiche le contenu
        if (snapshot.connectionState == ConnectionState.waiting) {
          return child;
        }

        // Vérifier si la maintenance est activée
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final isMaintenanceMode = data?['enabled'] == true;

        if (isMaintenanceMode) {
          return maintenanceFallback ?? _buildMaintenanceScreen(context, data);
        }

        return child;
      },
    );
  }

  Widget _buildMaintenanceScreen(
    BuildContext context,
    Map<String, dynamic>? data,
  ) {
    final message = data?['message'] as String? ??
        'L\'application est actuellement en maintenance.\nMerci de revenir plus tard.';
    final estimatedEnd = data?['estimatedEnd'] as Timestamp?;
    final title = data?['title'] as String? ?? 'Maintenance en cours';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 100,
                color: Colors.orange[700],
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (estimatedEnd != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Fin estimée',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDateTime(estimatedEnd.toDate()),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Rafraîchir la page pour vérifier si la maintenance est terminée
                  // Le StreamBuilder se chargera de mettre à jour automatiquement
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Rafraîchir'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      return 'Terminée';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days jour${days > 1 ? 's' : ''}');
    if (hours > 0) parts.add('$hours heure${hours > 1 ? 's' : ''}');
    if (minutes > 0 && days == 0) {
      parts.add('$minutes minute${minutes > 1 ? 's' : ''}');
    }

    final timeLeft = parts.isEmpty ? 'Bientôt' : 'Dans ${parts.join(' et ')}';

    return '$timeLeft\n${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Service pour gérer le mode maintenance
class MaintenanceService {
  static final instance = MaintenanceService._();
  MaintenanceService._();

  final _firestore = FirebaseFirestore.instance;

  /// Activer le mode maintenance
  Future<void> enableMaintenance({
    String? title,
    String? message,
    DateTime? estimatedEnd,
  }) async {
    await _firestore.collection('config').doc('maintenance').set({
      'enabled': true,
      'title': title ?? 'Maintenance en cours',
      'message': message ??
          'L\'application est actuellement en maintenance.\nMerci de revenir plus tard.',
      'estimatedEnd': estimatedEnd != null ? Timestamp.fromDate(estimatedEnd) : null,
      'startedAt': FieldValue.serverTimestamp(),
      'startedBy': null, // À remplir avec l'ID de l'admin
    }, SetOptions(merge: true));
  }

  /// Désactiver le mode maintenance
  Future<void> disableMaintenance() async {
    await _firestore.collection('config').doc('maintenance').set({
      'enabled': false,
      'endedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Vérifier si le mode maintenance est actif
  Future<bool> isMaintenanceActive() async {
    final doc = await _firestore.collection('config').doc('maintenance').get();
    final data = doc.data();
    return data?['enabled'] == true;
  }

  /// Obtenir les informations de maintenance
  Future<Map<String, dynamic>?> getMaintenanceInfo() async {
    final doc = await _firestore.collection('config').doc('maintenance').get();
    return doc.data();
  }

  /// Stream pour écouter les changements du mode maintenance
  Stream<bool> watchMaintenanceStatus() {
    return _firestore
        .collection('config')
        .doc('maintenance')
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      return data?['enabled'] == true;
    });
  }
}

/// Widget pour afficher l'état de maintenance dans l'interface admin
class MaintenanceStatusWidget extends StatelessWidget {
  const MaintenanceStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('maintenance')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final isEnabled = data?['enabled'] == true;

        if (!isEnabled) {
          return const SizedBox.shrink();
        }

        return Card(
          color: Colors.orange[50],
          child: ListTile(
            leading: Icon(Icons.construction, color: Colors.orange[700]),
            title: Text(
              'Mode maintenance actif',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            subtitle: Text(data?['message'] ?? ''),
            trailing: TextButton(
              onPressed: () {
                _showMaintenanceDialog(context);
              },
              child: const Text('Gérer'),
            ),
          ),
        );
      },
    );
  }

  void _showMaintenanceDialog(BuildContext context) {
    Navigator.of(context).pushNamed('/admin/maintenance');
  }
}

/// Page de gestion de la maintenance (pour les admins)
class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({super.key});

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  final _service = MaintenanceService.instance;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isEnabled = false;
  DateTime? _estimatedEnd;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMaintenanceInfo();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMaintenanceInfo() async {
    setState(() => _isLoading = true);
    try {
      final info = await _service.getMaintenanceInfo();
      if (info != null && mounted) {
        setState(() {
          _isEnabled = info['enabled'] == true;
          _titleController.text = info['title'] ?? '';
          _messageController.text = info['message'] ?? '';
          final endTimestamp = info['estimatedEnd'] as Timestamp?;
          _estimatedEnd = endTimestamp?.toDate();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleMaintenance() async {
    setState(() => _isSaving = true);
    try {
      if (_isEnabled) {
        await _service.disableMaintenance();
      } else {
        if (_formKey.currentState!.validate()) {
          await _service.enableMaintenance(
            title: _titleController.text.trim(),
            message: _messageController.text.trim(),
            estimatedEnd: _estimatedEnd,
          );
        } else {
          setState(() => _isSaving = false);
          return;
        }
      }
      await _loadMaintenanceInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEnabled
                  ? 'Mode maintenance désactivé'
                  : 'Mode maintenance activé',
            ),
          ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de la maintenance'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: _isEnabled ? Colors.orange[50] : Colors.green[50],
                child: SwitchListTile(
                  title: Text(
                    _isEnabled ? 'Maintenance activée' : 'Maintenance désactivée',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isEnabled ? Colors.orange[700] : Colors.green[700],
                    ),
                  ),
                  subtitle: Text(
                    _isEnabled
                        ? 'Les utilisateurs ne peuvent pas accéder à l\'application'
                        : 'L\'application fonctionne normalement',
                  ),
                  value: _isEnabled,
                  onChanged: _isSaving ? null : (_) => _toggleMaintenance(),
                  secondary: Icon(
                    _isEnabled ? Icons.construction : Icons.check_circle,
                    color: _isEnabled ? Colors.orange[700] : Colors.green[700],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (!_isEnabled && (value == null || value.trim().isEmpty)) {
                    return 'Le titre est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                  helperText: 'Message affiché aux utilisateurs',
                ),
                maxLines: 4,
                validator: (value) {
                  if (!_isEnabled && (value == null || value.trim().isEmpty)) {
                    return 'Le message est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Fin estimée'),
                subtitle: Text(
                  _estimatedEnd != null
                      ? '${_estimatedEnd!.day}/${_estimatedEnd!.month}/${_estimatedEnd!.year} à ${_estimatedEnd!.hour}:${_estimatedEnd!.minute.toString().padLeft(2, '0')}'
                      : 'Non définie',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _estimatedEnd ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                          _estimatedEnd ?? DateTime.now(),
                        ),
                      );
                      if (time != null && mounted) {
                        setState(() {
                          _estimatedEnd = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
