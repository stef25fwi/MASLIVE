import 'package:flutter/material.dart';
import '../services/cloud_function_service.dart';
import '../services/geolocation_service.dart';

class GroupMemberPage extends StatefulWidget {
  const GroupMemberPage({super.key, this.groupId});
  final String? groupId;

  @override
  State<GroupMemberPage> createState() => _GroupMemberPageState();
}

class _GroupMemberPageState extends State<GroupMemberPage> {
  final GeolocationService _geoService = GeolocationService.instance;
  bool _isTracking = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _isTracking = _geoService.isTracking;
  }

  @override
  void dispose() {
    // Ne pas arrêter le tracking à la sortie (important pour background)
    // _geoService.stopTracking();
    super.dispose();
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      // Arrêter
      _geoService.stopTracking();
      setState(() => _isTracking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking arrêté')),
      );
    } else {
      // Démarrer
      if (widget.groupId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun groupId associé au profil')),
        );
        return;
      }

      setState(() => _sending = true);
      try {
        final success = await _geoService.startTracking(
          groupId: widget.groupId!,
          intervalSeconds: 15,
        );
        if (!mounted) return;
        if (success) {
          setState(() => _isTracking = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Tracking démarré (15s)')),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Permissions GPS refusées')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    }
  }

  Future<void> _simulateUpdate() async {
    if (widget.groupId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun groupId associé au profil')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      // Coordonnées de démonstration (Pointe-à-Pitre)
      await CloudFunctionService().updateGroupLocation(
        groupId: widget.groupId!,
        lat: 16.2419,
        lng: -61.5337,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position envoyée (démo) ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupId = widget.groupId ?? 'groupe_demo';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groupe - Tracking'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Groupe: $groupId',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Activez la géolocalisation sur votre téléphone pour mettre à jour votre position toutes les 15s.',
            ),
            const SizedBox(height: 24),
            
            // ✅ Bouton principal : Démarrer/Arrêter tracking réel
            FilledButton.icon(
              onPressed: _sending ? null : _toggleTracking,
              icon: Icon(_isTracking ? Icons.stop_circle : Icons.my_location),
              label: Text(
                _sending
                    ? 'Patientez...'
                    : (_isTracking
                        ? 'Arrêter le tracking'
                        : 'Démarrer tracking GPS'),
              ),
            ),
            const SizedBox(height: 12),
            
            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isTracking ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isTracking ? Colors.green : Colors.grey,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isTracking ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: _isTracking ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isTracking
                        ? 'Tracking ACTIF (15s)'
                        : 'Tracking INACTIF',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _isTracking ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Mode Démo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // ✅ Bouton démo (position fixe)
            FilledButton.icon(
              onPressed: _sending ? null : _simulateUpdate,
              icon: const Icon(Icons.send),
              label: Text(_sending ? 'Envoi...' : 'Envoyer position démo'),
            ),
            const SizedBox(height: 12),
            
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/'),
              icon: const Icon(Icons.map),
              label: const Text('Voir la carte'),
            ),
            
            const Spacer(),
            
            const Text(
              '💡 Conseil : Active le tracking GPS pour envoyer ta position en continu toutes les 15 secondes à ton groupe.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
