import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_claims_service.dart';

class AdminRouteGuard extends StatelessWidget {
  const AdminRouteGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
      return const _AdminGuardLoading();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _AdminGuardLoading();
        }

        final user = authSnap.data;
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
          return const _AdminGuardLoading();
        }

        return StreamBuilder<AppUser?>(
          stream: AuthClaimsService.instance.getCurrentAppUserStream(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _AdminGuardLoading();
            }

            final appUser = userSnap.data;
            final isAdmin = appUser?.isAdminRole ?? false;

            if (!isAdmin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacementNamed('/');
              });
              return const _AdminGuardLoading();
            }

            return child;
          },
        );
      },
    );
  }
}

class _AdminGuardLoading extends StatelessWidget {
  const _AdminGuardLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
