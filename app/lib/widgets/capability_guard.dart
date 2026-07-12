import 'package:flutter/material.dart';

import '../security/profile_capability_policy.dart';

class CapabilityGuard extends StatelessWidget {
  const CapabilityGuard({
    super.key,
    required this.capability,
    required this.child,
    this.fallback,
    this.message,
  });

  final Capability capability;
  final Widget child;
  final Widget? fallback;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCapabilities?>(
      future: ProfileCapabilityPolicy.instance.resolveCurrent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return fallback ?? const SizedBox.shrink();
        }

        final profile = snapshot.data;
        if (profile != null && profile.isActive && profile.can(capability)) {
          return child;
        }

        return fallback ?? _CapabilityDenied(message: message);
      },
    );
  }
}

class _CapabilityDenied extends StatelessWidget {
  const _CapabilityDenied({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message ?? 'Action non disponible avec votre profil actuel.',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
