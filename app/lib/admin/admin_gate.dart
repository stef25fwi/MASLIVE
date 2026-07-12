import 'package:flutter/material.dart';

import '../security/profile_capability_policy.dart';

/// Gate pour protéger l'accès aux pages d'administration.
///
/// Utilise la politique de capacités centralisée au lieu du simple booléen
/// historique `isAdmin`.
class AdminGate extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final bool requireSuperAdmin;
  final Capability requiredCapability;

  const AdminGate({
    super.key,
    required this.child,
    this.fallback,
    this.requireSuperAdmin = false,
    this.requiredCapability = Capability.accessAdminPanel,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCapabilities?>(
      future: ProfileCapabilityPolicy.instance.resolveCurrent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final profile = snapshot.data;

        if (profile == null) {
          return _buildAccessDenied(
            context,
            'Non authentifié',
            'Vous devez être connecté pour accéder à cette page.',
          );
        }

        if (!profile.isActive) {
          return _buildAccessDenied(
            context,
            'Compte désactivé',
            'Votre compte a été désactivé. Contactez un administrateur.',
          );
        }

        final hasAccess = requireSuperAdmin
            ? profile.can(Capability.manageRoles)
            : profile.can(requiredCapability);

        if (!hasAccess) {
          return _buildAccessDenied(
            context,
            'Accès refusé',
            requireSuperAdmin
                ? 'Cette page est réservée aux super administrateurs.'
                : 'Cette page est réservée aux profils autorisés.',
          );
        }

        return child;
      },
    );
  }

  Widget _buildAccessDenied(BuildContext context, String title, String message) {
    if (fallback != null) return fallback!;

    return Scaffold(
      appBar: AppBar(title: const Text('Accès refusé')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget de protection pour les fonctionnalités admin inline.
class AdminOnly extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final bool requireSuperAdmin;
  final Capability requiredCapability;

  const AdminOnly({
    super.key,
    required this.child,
    this.fallback,
    this.requireSuperAdmin = false,
    this.requiredCapability = Capability.accessAdminPanel,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCapabilities?>(
      future: ProfileCapabilityPolicy.instance.resolveCurrent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return fallback ?? const SizedBox.shrink();
        }

        final profile = snapshot.data;
        if (profile == null || !profile.isActive) {
          return fallback ?? const SizedBox.shrink();
        }

        final hasAccess = requireSuperAdmin
            ? profile.can(Capability.manageRoles)
            : profile.can(requiredCapability);

        if (!hasAccess) {
          return fallback ?? const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}

extension AdminAccessContext on BuildContext {
  Future<bool> isAdmin() async {
    final profile = await ProfileCapabilityPolicy.instance.resolveCurrent();
    return profile?.can(Capability.accessAdminPanel) ?? false;
  }

  Future<bool> isSuperAdmin() async {
    final profile = await ProfileCapabilityPolicy.instance.resolveCurrent();
    return profile?.can(Capability.manageRoles) ?? false;
  }

  Future<bool> canAccessAdminPanel() async => isAdmin();

  Future<void> requireAdmin({String? message}) async {
    if (!await isAdmin()) {
      throw Exception(message ?? 'Accès administrateur requis');
    }
  }

  Future<void> requireSuperAdmin({String? message}) async {
    if (!await isSuperAdmin()) {
      throw Exception(message ?? 'Accès super administrateur requis');
    }
  }
}
