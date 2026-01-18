import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';

/// Route d'aiguillage selon le rôle Firestore.
class RoleRouterPage extends StatelessWidget {
  const RoleRouterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!userSnap.hasData || userSnap.data == null) {
          // ✅ Redirection vers la carte publique au lieu de login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = userSnap.data!;
        return StreamBuilder<UserProfile?>(
          stream: auth.getUserProfileStream(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnap.data;
            if (profile == null) {
              Navigator.of(context).pushReplacementNamed('/login');
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Naviguer après le build pour éviter les setState en build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              switch (profile.role) {
                case UserRole.admin:
                  Navigator.of(context).pushReplacementNamed('/admin');
                  break;
                case UserRole.group:
                  Navigator.of(context).pushReplacementNamed(
                    '/app',
                    arguments: {'groupId': profile.groupId},
                  );
                  break;
                case UserRole.user:
                  Navigator.of(context).pushReplacementNamed('/user');
                  break;
              }
            });

            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
  }
}
