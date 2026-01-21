import 'package:flutter/material.dart';
import '../services/auth_claims_service.dart';
import '../models/app_user.dart';

/// Gate pour protéger l'accès aux pages d'administration
class AdminGate extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final bool requireSuperAdmin;

  const AdminGate({
    super.key,
    required this.child,
    this.fallback,
    this.requireSuperAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: AuthClaimsService.instance.getCurrentAppUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return _buildAccessDenied(
            context,
            'Non authentifié',
            'Vous devez être connecté pour accéder à cette page.',
          );
        }

        if (!user.isActive) {
          return _buildAccessDenied(
            context,
            'Compte désactivé',
            'Votre compte a été désactivé. Contactez un administrateur.',
          );
        }

        // Vérifier les permissions
        final hasAccess = requireSuperAdmin 
            ? user.isSuperAdmin 
            : user.isAdminRole;

        if (!hasAccess) {
          return _buildAccessDenied(
            context,
            'Accès refusé',
            requireSuperAdmin
                ? 'Cette page est réservée aux super administrateurs.'
                : 'Cette page est réservée aux administrateurs.',
          );
        }

        return child;
      },
    );
  }

  Widget _buildAccessDenied(
    BuildContext context,
    String title,
    String message,
  ) {
    if (fallback != null) {
      return fallback!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accès refusé'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 64,
                color: Colors.red,
              ),
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

/// Widget de protection pour les fonctionnalités admin inline
class AdminOnly extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final bool requireSuperAdmin;

  const AdminOnly({
    super.key,
    required this.child,
    this.fallback,
    this.requireSuperAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: AuthClaimsService.instance.getCurrentAppUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return fallback ?? const SizedBox.shrink();
        }

        final user = snapshot.data;
        if (user == null || !user.isActive) {
          return fallback ?? const SizedBox.shrink();
        }

        final hasAccess = requireSuperAdmin 
            ? user.isSuperAdmin 
            : user.isAdminRole;

        if (!hasAccess) {
          return fallback ?? const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}

/// Extension pour faciliter les vérifications d'accès admin
extension AdminAccessContext on BuildContext {
  Future<bool> isAdmin() async {
    return await AuthClaimsService.instance.isCurrentUserAdmin();
  }

  Future<bool> isSuperAdmin() async {
    return await AuthClaimsService.instance.isCurrentUserSuperAdmin();
  }

  Future<bool> canAccessAdminPanel() async {
    return await AuthClaimsService.instance.canAccessAdminPanel();
  }

  Future<void> requireAdmin({String? message}) async {
    final hasAccess = await isAdmin();
    if (!hasAccess) {
      throw Exception(message ?? 'Accès administrateur requis');
    }
  }

  Future<void> requireSuperAdmin({String? message}) async {
    final hasAccess = await isSuperAdmin();
    if (!hasAccess) {
      throw Exception(message ?? 'Accès super administrateur requis');
    }
  }
}
