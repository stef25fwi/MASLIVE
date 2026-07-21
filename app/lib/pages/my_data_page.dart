import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

import '../services/auth_service.dart';

/// Écran « Mes données personnelles » (RGPD) : permet à l'utilisateur
/// d'exercer son droit d'accès/portabilité (export) et son droit à
/// l'effacement (suppression du compte), en s'appuyant sur les Cloud
/// Functions `exportMyPersonalData` et `deleteMyAccountGdpr`.
class MyDataPage extends StatefulWidget {
  const MyDataPage({super.key});

  @override
  State<MyDataPage> createState() => _MyDataPageState();
}

class _MyDataPageState extends State<MyDataPage> {
  bool _exporting = false;
  bool _deleting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final data = await AuthService.instance.exportMyPersonalData();
      if (!mounted) return;
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      await _showExportResult(pretty);
    } catch (error) {
      if (!mounted) return;
      _showSnack('Export impossible : $error', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showExportResult(String pretty) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vos données'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              pretty,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pretty));
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              _showSnack('Données copiées dans le presse-papiers.');
            },
            child: const Text('Copier'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte ?'),
        content: const Text(
          'Cette action est définitive. Votre compte et vos données '
          'personnelles seront supprimés (profil, contenus, historique). '
          'Certaines données peuvent être conservées si la loi l\'impose '
          '(ex. facturation).\n\nSouhaitez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MasliveTokens.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await AuthService.instance.deleteAccount();
      // On nettoie la session locale puis on renvoie à l'accueil.
      try {
        await AuthService.instance.signOut();
      } catch (_) {
        // ignore : le compte est déjà supprimé côté serveur.
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      _showSnack('Votre compte a été supprimé.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showSnack('Suppression impossible : $error', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? MasliveTokens.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MasliveTokens.bg,
      appBar: AppBar(
        title: const Text('Mes données personnelles'),
        backgroundColor: Colors.white,
        foregroundColor: MasliveTokens.text,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Conformément au RGPD, vous pouvez à tout moment obtenir une copie '
            'de vos données ou demander la suppression de votre compte.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: MasliveTokens.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          _DataCard(
            icon: Icons.download_outlined,
            iconColor: MasliveTokens.primary,
            title: 'Exporter mes données',
            description:
                'Obtenez une copie de vos données personnelles (profil, '
                'contenus, historique) au format JSON.',
            buttonLabel: 'Exporter',
            busy: _exporting,
            onPressed: _export,
          ),
          const SizedBox(height: 14),
          _DataCard(
            icon: Icons.delete_outline,
            iconColor: MasliveTokens.danger,
            title: 'Supprimer mon compte',
            description:
                'Supprime définitivement votre compte et vos données '
                'personnelles associées. Cette action est irréversible.',
            buttonLabel: 'Supprimer mon compte',
            danger: true,
            busy: _deleting,
            onPressed: _confirmAndDelete,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/legal'),
              child: const Text('Mentions légales & CGU'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.busy,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonLabel;
  final bool busy;
  final bool danger;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MasliveTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: MasliveTokens.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: MasliveTokens.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: danger
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MasliveTokens.danger,
                      side: const BorderSide(color: MasliveTokens.danger),
                    ),
                    onPressed: busy ? null : onPressed,
                    child: _label(busy, buttonLabel),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MasliveTokens.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: busy ? null : onPressed,
                    child: _label(busy, buttonLabel),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _label(bool busy, String text) {
    if (!busy) return Text(text);
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
