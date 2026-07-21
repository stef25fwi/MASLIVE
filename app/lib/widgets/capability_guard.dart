import 'package:flutter/material.dart';

import '../security/profile_capability_policy.dart';

class CapabilityGuard extends StatelessWidget {
  const CapabilityGuard({
    super.key,
    required this.capability,
    required this.child,
    this.fallback,
    this.message,
    this.fullPage = false,
  })  : anyOf = const <Capability>[],
        allOf = const <Capability>[];

  const CapabilityGuard.any({
    super.key,
    required this.anyOf,
    required this.child,
    this.fallback,
    this.message,
    this.fullPage = false,
  })  : capability = null,
        allOf = const <Capability>[];

  const CapabilityGuard.all({
    super.key,
    required this.allOf,
    required this.child,
    this.fallback,
    this.message,
    this.fullPage = false,
  })  : capability = null,
        anyOf = const <Capability>[];

  final Capability? capability;
  final List<Capability> anyOf;
  final List<Capability> allOf;
  final Widget child;
  final Widget? fallback;
  final String? message;
  final bool fullPage;

  bool _isAllowed(ProfileCapabilities profile) {
    if (!profile.isActive) return false;
    if (capability != null) return profile.can(capability!);
    if (anyOf.isNotEmpty) return anyOf.any(profile.can);
    if (allOf.isNotEmpty) return allOf.every(profile.can);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCapabilities?>(
      future: ProfileCapabilityPolicy.instance.resolveCurrent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return fallback ??
              (fullPage
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink());
        }

        final profile = snapshot.data;
        if (profile != null && _isAllowed(profile)) return child;

        if (fallback != null) return fallback!;
        return _CapabilityDenied(message: message, fullPage: fullPage);
      },
    );
  }
}

class _CapabilityDenied extends StatelessWidget {
  const _CapabilityDenied({this.message, required this.fullPage});

  final String? message;
  final bool fullPage;

  Widget _content(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.lock_outline_rounded,
              size: 52,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 14),
            Text(
              message ?? 'Action non disponible avec votre profil actuel.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            if (fullPage) ...<Widget>[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/account-ui'),
                child: const Text('Retour à mon profil'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (fullPage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: _content(context),
      );
    }
    return Card(margin: EdgeInsets.zero, child: _content(context));
  }
}
