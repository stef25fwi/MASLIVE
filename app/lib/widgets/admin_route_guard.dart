import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../security/profile_capability_policy.dart';

class AdminRouteGuard extends StatelessWidget {
  const AdminRouteGuard({
    super.key,
    required this.child,
    this.requiredCapability = Capability.accessAdminPanel,
    this.requireSuperAdmin = false,
    this.allowMobile = false,
  });

  final Widget child;
  final Capability requiredCapability;
  final bool requireSuperAdmin;
  final bool allowMobile;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isMobile && !allowMobile) {
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

        return FutureBuilder<ProfileCapabilities?>(
          future: ProfileCapabilityPolicy.instance.resolveCurrent(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const _AdminGuardLoading();
            }

            final profile = profileSnap.data;
            final hasAccess = profile != null &&
                profile.isActive &&
                (requireSuperAdmin
                    ? profile.can(Capability.manageRoles)
                    : profile.can(requiredCapability));

            if (!hasAccess) {
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
    return const Scaffold(
      body: ColoredBox(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 34,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(height: 12),
                Text(
                  'Vérification de l’accès admin...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
