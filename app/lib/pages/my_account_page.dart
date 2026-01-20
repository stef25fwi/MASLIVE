import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({super.key});

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  final AuthService _authService = AuthService();
  final TextEditingController _pseudoController = TextEditingController();
  String _selectedCountry = 'France';
  bool _isEditing = false;

  final List<String> _countries = [
    'France',
    'Guadeloupe',
    'Martinique',
    'Guyane',
    'Réunion',
    'Mayotte',
    'Belgique',
    'Suisse',
    'Canada',
    'Autre',
  ];

  @override
  void dispose() {
    _pseudoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Compte'),
        elevation: 0,
      ),
      body: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnap.hasData || userSnap.data == null) {
            return _buildNotAuthenticated(context);
          }

          final user = userSnap.data!;
          return _buildAuthenticated(context, user);
        },
      ),
    );
  }

  // ✅ Utilisateur non connecté
  Widget _buildNotAuthenticated(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text('Vous n\'êtes pas connecté',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('Connectez-vous pour accéder à votre profil',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.login),
            label: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  // ✅ Utilisateur connecté
  Widget _buildAuthenticated(BuildContext context, User user) {
    return StreamBuilder<UserProfile?>(
      stream: _authService.getUserProfileStream(user.uid),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Avatar et infos de base
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.displayName ?? 'Utilisateur',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 16,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel(profile),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ✅ Section Infos Personnelles
              _buildSectionTitle('Informations Personnelles'),
              const SizedBox(height: 12),
              _buildEditableField(
                controller: _pseudoController,
                label: 'Pseudo',
                icon: Icons.person,
                initialValue: user.displayName,
                enabled: _isEditing,
              ),
              const SizedBox(height: 12),
              _buildCountryDropdown(
                enabled: _isEditing,
                initialValue: profile?.region,
              ),
              const SizedBox(height: 20),

              // ✅ Bouton Sauvegarder/Modifier
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_isEditing) {
                      _saveProfile(user);
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                  child: Text(_isEditing ? 'Sauvegarder les modifications' : 'Modifier'),
                ),
              ),
              const SizedBox(height: 32),

              // ✅ Section Sécurité
              _buildSectionTitle('Sécurité'),
              const SizedBox(height: 12),
              _buildActionTile(
                icon: Icons.lock,
                title: 'Changer le mot de passe',
                subtitle: 'Mettre à jour votre mot de passe',
                onTap: () => _showChangePasswordDialog(context),
              ),
              const SizedBox(height: 8),
              _buildActionTile(
                icon: Icons.logout,
                title: 'Déconnexion',
                subtitle: 'Se déconnecter de votre compte',
                onTap: () => _showLogoutDialog(context),
                color: Colors.red,
              ),
              const SizedBox(height: 32),

              // ✅ Section Danger
              _buildSectionTitle('Zone Dangereuse', isRed: true),
              const SizedBox(height: 12),
              _buildActionTile(
                icon: Icons.delete,
                title: 'Supprimer le compte',
                subtitle: 'Cette action est irréversible',
                onTap: () => _showDeleteAccountDialog(context),
                color: Colors.red,
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(UserProfile? profile) {
    if (profile == null) return 'Utilisateur connecté';
    if (profile.isAdmin || profile.role == UserRole.admin) return 'Admin';
    if (profile.role == UserRole.group) return 'Admin de groupe';
    return 'Membre';
  }

  Widget _buildSectionTitle(String title, {bool isRed = false}) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isRed ? Colors.red : Colors.black87,
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? initialValue,
    required bool enabled,
  }) {
    controller.text = initialValue ?? '';

    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: !enabled,
        fillColor: !enabled ? Colors.grey[200] : null,
      ),
    );
  }

  Widget _buildCountryDropdown({
    required bool enabled,
    String? initialValue,
  }) {
    if (initialValue != null && _countries.contains(initialValue)) {
      _selectedCountry = initialValue;
    }

    return DropdownButtonFormField<String>(
      value: _selectedCountry,
      decoration: InputDecoration(
        labelText: 'Pays',
        prefixIcon: const Icon(Icons.public),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: !enabled,
        fillColor: !enabled ? Colors.grey[200] : null,
      ),
      items: _countries.map((country) {
        return DropdownMenuItem(
          value: country,
          child: Text(country),
        );
      }).toList(),
      onChanged: enabled
          ? (value) {
              if (value != null) {
                setState(() => _selectedCountry = value);
              }
            }
          : null,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        )),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _saveProfile(User user) {
    _authService
        .updateUserProfile(
          displayName: _pseudoController.text.isNotEmpty
              ? _pseudoController.text
              : null,
          region: _selectedCountry,
        )
        .then((_) {
          if (!mounted) {
            return;
          }
          setState(() => _isEditing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil mis à jour ✓')),
          );
        })
        .catchError((e) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        });
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Un lien de réinitialisation sera envoyé à votre email.'),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              _authService.resetPassword(_authService.currentUser!.email!);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email de réinitialisation envoyé ✓'),
                ),
              );
            },
            child: const Text('Envoyer le lien'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              _authService.signOut();
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text(
          'Cette action est définitive et irréversible. Tous vos données seront supprimées.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              _authService.deleteAccount().then((_) {
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              }).catchError((e) {
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              });
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }
}
