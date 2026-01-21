import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_claims_service.dart';
import '../models/app_user.dart';

/// Modèle pour un message système
class SystemMessage {
  final String id;
  final String title;
  final String message;
  final SystemMessageType type;
  final SystemMessagePriority priority;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? createdBy;
  final List<String>? targetRoles; // null = tous les utilisateurs
  final String? actionUrl;
  final String? actionLabel;

  SystemMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.createdAt,
    this.expiresAt,
    required this.isActive,
    this.createdBy,
    this.targetRoles,
    this.actionUrl,
    this.actionLabel,
  });

  factory SystemMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SystemMessage(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: SystemMessageType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => SystemMessageType.info,
      ),
      priority: SystemMessagePriority.values.firstWhere(
        (e) => e.toString().split('.').last == data['priority'],
        orElse: () => SystemMessagePriority.normal,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      createdBy: data['createdBy'],
      targetRoles: data['targetRoles'] != null
          ? List<String>.from(data['targetRoles'])
          : null,
      actionUrl: data['actionUrl'],
      actionLabel: data['actionLabel'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'createdBy': createdBy,
      'targetRoles': targetRoles,
      'actionUrl': actionUrl,
      'actionLabel': actionLabel,
    };
  }

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool isVisibleForUser(AppUser? user) {
    if (!isActive || isExpired) return false;
    if (targetRoles == null || targetRoles!.isEmpty) return true;
    if (user == null) return false;
    return targetRoles!.contains(user.role.toString().split('.').last);
  }
}

enum SystemMessageType {
  info,
  warning,
  error,
  success,
  maintenance,
  update,
}

enum SystemMessagePriority {
  low,
  normal,
  high,
  urgent,
}

/// Page d'affichage des messages système
class SystemMessagesPage extends StatefulWidget {
  const SystemMessagesPage({super.key});

  @override
  State<SystemMessagesPage> createState() => _SystemMessagesPageState();
}

class _SystemMessagesPageState extends State<SystemMessagesPage> {
  final _authService = AuthClaimsService.instance;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentAppUser();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages système'),
        actions: [
          if (_currentUser?.isAdminRole == true)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateMessageDialog(),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('system_messages')
            .orderBy('priority', descending: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data!.docs
              .map((doc) => SystemMessage.fromFirestore(doc))
              .where((msg) => msg.isVisibleForUser(_currentUser))
              .toList();

          if (messages.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucun message système',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return _buildMessageCard(messages[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageCard(SystemMessage message) {
    final color = _getMessageColor(message.type);
    final icon = _getMessageIcon(message.type);
    final priorityBadge = _getPriorityBadge(message.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showMessageDetails(message),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 4),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (priorityBadge != null) priorityBadge,
                    if (_currentUser?.isAdminRole == true) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Modifier'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Supprimer', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteMessage(message);
                          }
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatDate(message.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (message.expiresAt != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Expire le ${_formatDate(message.expiresAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                if (message.actionUrl != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Implémenter la navigation vers l'URL
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(message.actionLabel ?? 'Voir plus'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _getPriorityBadge(SystemMessagePriority priority) {
    switch (priority) {
      case SystemMessagePriority.urgent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning, size: 12, color: Colors.red.shade700),
              const SizedBox(width: 4),
              Text(
                'URGENT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        );
      case SystemMessagePriority.high:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Important',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
        );
      default:
        return null;
    }
  }

  Color _getMessageColor(SystemMessageType type) {
    switch (type) {
      case SystemMessageType.error:
        return Colors.red;
      case SystemMessageType.warning:
        return Colors.orange;
      case SystemMessageType.success:
        return Colors.green;
      case SystemMessageType.maintenance:
        return Colors.orange;
      case SystemMessageType.update:
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  IconData _getMessageIcon(SystemMessageType type) {
    switch (type) {
      case SystemMessageType.error:
        return Icons.error;
      case SystemMessageType.warning:
        return Icons.warning;
      case SystemMessageType.success:
        return Icons.check_circle;
      case SystemMessageType.maintenance:
        return Icons.construction;
      case SystemMessageType.update:
        return Icons.system_update;
      default:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showMessageDetails(SystemMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getMessageIcon(message.type),
              color: _getMessageColor(message.type),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message.message),
              const SizedBox(height: 16),
              Text(
                'Publié le ${_formatDate(message.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (message.expiresAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Expire le ${_formatDate(message.expiresAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          if (message.actionUrl != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Implémenter la navigation
              },
              child: Text(message.actionLabel ?? 'Voir plus'),
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateMessageDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    SystemMessageType type = SystemMessageType.info;
    SystemMessagePriority priority = SystemMessagePriority.normal;
    DateTime? expiresAt;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nouveau message système'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SystemMessageType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: SystemMessageType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.toString().split('.').last),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => type = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SystemMessagePriority>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                    labelText: 'Priorité',
                    border: OutlineInputBorder(),
                  ),
                  items: SystemMessagePriority.values
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.toString().split('.').last),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => priority = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    messageController.text.isNotEmpty) {
                  await _createMessage(
                    titleController.text,
                    messageController.text,
                    type,
                    priority,
                    expiresAt,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createMessage(
    String title,
    String message,
    SystemMessageType type,
    SystemMessagePriority priority,
    DateTime? expiresAt,
  ) async {
    try {
      final messageData = {
        'title': title,
        'message': message,
        'type': type.toString().split('.').last,
        'priority': priority.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'isActive': true,
        'createdBy': _currentUser?.uid,
      };

      await FirebaseFirestore.instance
          .collection('system_messages')
          .add(messageData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message créé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(SystemMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer le message "${message.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('system_messages')
            .doc(message.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }
}
