import 'package:flutter/material.dart';
import '../services/auth_claims_service.dart';

class CreateCircuitFeaturesPage extends StatefulWidget {
  const CreateCircuitFeaturesPage({super.key});

  @override
  State<CreateCircuitFeaturesPage> createState() => _CreateCircuitFeaturesPageState();
}

class _CreateCircuitFeaturesPageState extends State<CreateCircuitFeaturesPage> {
  bool _isLoading = true;
  bool _isSuperAdmin = false;

  static const _bg = Colors.white;
  static const _text = Color(0xFF1F2A37);      // bleu/noir élégant
  static const _sub = Color(0xFF6B7280);       // gris iOS
  static const _line = Color(0xFFE5E7EB);      // séparateurs

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final isSuperAdmin = await AuthClaimsService.instance.isCurrentUserSuperAdmin();
    setState(() {
      _isSuperAdmin = isSuperAdmin;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Accès refusé'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Accès réservé aux Super Admins',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vous n\'avez pas les permissions nécessaires',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }
    final sections = <_StepSectionData>[
      _StepSectionData(
        index: 1,
        title: "Dessiner le Circuit",
        color: const Color(0xFFEA580C), // orange
        icon: Icons.edit_location_alt_rounded,
        bullets: const [
          "Tracer & Éditer la route",
          "Définir point départ & arrivée",
          "Ajouter POIs sur le parcours",
          "Simplifier & lisser le tracé",
        ],
      ),
      _StepSectionData(
        index: 2,
        title: "Importer / Exporter",
        color: const Color(0xFFF59E0B), // orange clair
        icon: Icons.folder_copy_rounded,
        bullets: const [
          "Importer GPX / KML",
          "Exporter en GPX",
          "Dupliquer un circuit",
        ],
      ),
      _StepSectionData(
        index: 3,
        title: "Calculs & Validation",
        color: const Color(0xFF1A73E8), // bleu
        icon: Icons.verified_user_rounded,
        bullets: const [
          "Distance & Dénivelé",
          "Temps estimé",
          "Validation automatique",
        ],
      ),
      _StepSectionData(
        index: 4,
        title: "Sauvegarder & Publier",
        color: const Color(0xFF34A853), // vert
        icon: Icons.cloud_upload_rounded,
        bullets: const [
          "Sauvegarde auto",
          "Publier le Circuit",
          "Archives & Versions",
          "Mode hors-ligne",
        ],
      ),
      _StepSectionData(
        index: 5,
        title: "Rechercher des Circuits",
        color: const Color(0xFFF97316), // orange
        icon: Icons.manage_search_rounded,
        bullets: const [
          "Bibliothèque de circuits",
          "Recherche & Filtres",
          "Circuits à proximité",
        ],
      ),
      _StepSectionData(
        index: 6,
        title: "Navigation & Suivi",
        color: const Color(0xFF22C55E), // vert
        icon: Icons.navigation_rounded,
        bullets: const [
          "Navigation en Live",
          "Progression sur le tracé",
          "Détection \"Hors-Route\"",
        ],
      ),
      _StepSectionData(
        index: 7,
        title: "Avis & Signalement",
        color: const Color(0xFFF59E0B), // orange
        icon: Icons.star_rate_rounded,
        bullets: const [
          "Note & Commentaires",
          "Signaler Problème",
          "Circuit Vérifié",
        ],
      ),
      _StepSectionData(
        index: 8,
        title: "Import / Équipe",
        color: const Color(0xFF2563EB), // bleu
        icon: Icons.group_add_rounded,
        bullets: const [
          "Importer GPX / KML",
          "Collaborer & Partager",
          "Inviter un co-éditeur",
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                  child: Column(
                    children: [
                      for (int i = 0; i < sections.length; i++) ...[
                        _StepSection(
                          data: sections[i],
                          textColor: _text,
                          lineColor: _line,
                          subColor: _sub,
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1, thickness: 1, color: _line),
                        const SizedBox(height: 18),
                      ],
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  static const _text = Color(0xFF1F2A37);
  static const _sub = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line, width: 1)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: _text),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "Créer un Circuit",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  height: 1.05,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Étapes et Fonctionnalités",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _sub,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepSectionData {
  final int index;
  final String title;
  final Color color;
  final IconData icon;
  final List<String> bullets;

  const _StepSectionData({
    required this.index,
    required this.title,
    required this.color,
    required this.icon,
    required this.bullets,
  });
}

class _StepSection extends StatelessWidget {
  final _StepSectionData data;
  final Color textColor;
  final Color subColor;
  final Color lineColor;

  const _StepSection({
    required this.data,
    required this.textColor,
    required this.subColor,
    required this.lineColor,
  });

  void _handleTap(BuildContext context) {
    // Actions selon la section
    switch (data.index) {
      case 1: // Dessiner le Circuit
        Navigator.pushNamed(context, '/circuit-draw');
        break;
      case 2: // Importer / Exporter
        Navigator.pushNamed(context, '/circuit-import-export');
        break;
      case 3: // Calculs & Validation
        Navigator.pushNamed(context, '/circuit-calculs');
        break;
      case 4: // Sauvegarder & Publier
        Navigator.pushNamed(context, '/admin/circuits');
        break;
      case 5: // Rechercher des Circuits
        Navigator.pushNamed(context, '/search');
        break;
      case 6: // Navigation & Suivi
        Navigator.pushNamed(context, '/tracking');
        break;
      case 7: // Avis & Signalement
        Navigator.pushNamed(context, '/favorites');
        break;
      case 8: // Import / Équipe
        Navigator.pushNamed(context, '/map-admin');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleTap(context),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AppIconSquare(color: data.color, icon: data.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre + ligne à droite (comme ton mockup)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "${data.index}. ${data.title}",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          height: 1.1,
                          letterSpacing: -0.15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 2),
                          height: 1,
                          color: lineColor,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...data.bullets.map((t) => _BulletLine(text: t, dotColor: data.color, textColor: textColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIconSquare extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _AppIconSquare({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Petit "shine" iOS
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Center(
            child: Icon(icon, size: 30, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  final Color dotColor;
  final Color textColor;

  const _BulletLine({
    required this.text,
    required this.dotColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
