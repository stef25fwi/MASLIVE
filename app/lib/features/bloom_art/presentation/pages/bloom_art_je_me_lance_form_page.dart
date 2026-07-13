import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/bloom_art_seller_profile.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_cta_button.dart';

class BloomArtJeMeLanceFormPage extends StatefulWidget {
  const BloomArtJeMeLanceFormPage({super.key});

  @override
  State<BloomArtJeMeLanceFormPage> createState() =>
      _BloomArtJeMeLanceFormPageState();
}

class _BloomArtJeMeLanceFormPageState
    extends State<BloomArtJeMeLanceFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final BloomArtRepository _repository = BloomArtRepository();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _artistNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _projectNoteController = TextEditingController();

  static const List<String> _regions = <String>[
    'Guadeloupe',
    'Martinique',
    'Guyane',
    'La Réunion',
    'Mayotte',
    'Hexagone / autre région',
  ];

  static const List<String> _statuses = <String>[
    'Fonctionnaire',
    'Demandeur d’emploi',
    'Étudiant',
    'Indépendant',
    'Sans activité',
    'Retraité',
  ];

  bool _loading = true;
  bool _saving = false;
  String _region = 'Guadeloupe';
  String _currentStatus = 'Sans activité';
  String _creationType = BloomArtCreationType.artisanatArt;
  DateTime? _createdAt;

  _LaunchGuide get _guide => _LaunchGuide.forSelection(
        region: _region,
        status: _currentStatus,
        creationType: _creationType,
        projectNote: _projectNoteController.text,
      );

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _projectNoteController.addListener(_refreshGuidePreview);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _artistNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _projectNoteController.removeListener(_refreshGuidePreview);
    _projectNoteController.dispose();
    super.dispose();
  }

  void _refreshGuidePreview() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    _fullNameController.text = (user.displayName ?? '').trim();
    _emailController.text = (user.email ?? '').trim();

    final profile = await _repository.getSellerProfile(user.uid);
    if (!mounted) return;

    if (profile != null) {
      final guide = profile.launchGuideData;
      _createdAt = profile.createdAt;
      _fullNameController.text = profile.fullName;
      _artistNameController.text = profile.artistName;
      _emailController.text = profile.email;
      _phoneController.text = profile.phone;
      _projectNoteController.text = profile.bio;
      _creationType = BloomArtCreationType.normalize(profile.creationType);
      _region = _normalizeRegion(
        (guide['region'] ?? profile.region).toString(),
      );
      _currentStatus = _normalizeStatus(
        (guide['currentStatus'] ?? guide['status'] ?? '').toString(),
      );
    }

    setState(() => _loading = false);
  }

  String _normalizeRegion(String value) {
    final clean = value.trim();
    return _regions.contains(clean) ? clean : _regions.first;
  }

  String _normalizeStatus(String value) {
    final clean = value.trim();
    return _statuses.contains(clean) ? clean : 'Sans activité';
  }

  Map<String, dynamic> _buildLaunchGuideData() {
    final guide = _guide;
    final activityLabel = BloomArtCreationType.labelOf(_creationType);
    return <String, dynamic>{
      'savedAt': DateTime.now().toIso8601String(),
      'source': 'bloom_art_maslive_parcours_personnalise',
      'projectLabel': 'Galerie Bloom Art — $activityLabel',
      'region': _region,
      'currentStatus': _currentStatus,
      'selectedActivity': activityLabel,
      'creationType': _creationType,
      'recommendation': guide.recommendation,
      'blockingAlerts': guide.blockingAlerts,
      'aides': guide.aides,
      'plan30': guide.plan30,
      'summary': guide.summary,
      'recommendedLegalStatus': guide.recommendedLegalStatus,
      'statusWarnings': guide.statusWarnings,
      'steps': guide.steps,
    };
  }

  Future<void> _saveGuideProgress({bool goToSiret = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pushNamed('/login');
      return;
    }

    setState(() => _saving = true);
    try {
      final guideData = _buildLaunchGuideData();
      final guide = _guide;
      final profile = BloomArtSellerProfile(
        id: user.uid,
        userId: user.uid,
        profileType: 'je_me_lance',
        creationType: _creationType,
        fullName: _fullNameController.text.trim(),
        artistName: _artistNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        bio: _projectNoteController.text.trim(),
        address: '',
        city: '',
        postalCode: '',
        region: _region,
        country: 'France',
        payoutStatus: 'pending',
        stripeAccountLinked: false,
        sellerStatus: guide.canStartSiretNow
            ? 'launch_guide_ready'
            : 'launch_guide_started',
        businessVerificationStatus: 'missing_siret',
        businessVerificationSource: 'bloom_art_launch_guide',
        launchGuideData: guideData,
        createdAt: _createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _repository.saveSellerProfile(profile);
      if (!mounted) return;

      if (goToSiret) {
        Navigator.of(context).pushReplacementNamed(
          '/bloom-art/sell',
          arguments: <String, dynamic>{'selectedType': 'artisan_art'},
        );
      } else {
        Navigator.of(context).pushReplacementNamed('/bloom-art/dashboard');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’enregistrer le parcours : $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF7),
        elevation: 0,
        title: const Text(
          'Je me lance',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 28),
                children: <Widget>[
                  const _BloomArtLaunchHero(),
                  const SizedBox(height: 18),
                  _MenuCard(
                    title: 'Parcours personnalisé',
                    subtitle:
                        'Choisissez votre région, votre activité artisan d’art et votre statut actuel. Bloom Art génère ensuite un guide de création de statut avant la vente.',
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: _region,
                        decoration: const InputDecoration(
                          labelText: 'Région',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _regions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() => _region = _normalizeRegion(value ?? ''));
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _creationType,
                        decoration: const InputDecoration(
                          labelText: 'Activité artisan d’art',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: BloomArtCreationType.values
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(BloomArtCreationType.labelOf(value)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() {
                            _creationType = BloomArtCreationType.normalize(value);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _currentStatus,
                        decoration: const InputDecoration(
                          labelText: 'Statut actuel',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _statuses
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() => _currentStatus = _normalizeStatus(value ?? ''));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _MenuCard(
                    title: 'Contact du projet',
                    subtitle:
                        'Ces informations servent à enregistrer votre parcours Bloom Art. Elles ne publient pas encore d’œuvre.',
                    children: <Widget>[
                      _BloomArtTextField(
                        controller: _fullNameController,
                        label: 'Nom complet',
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 12),
                      _BloomArtTextField(
                        controller: _artistNameController,
                        label: 'Nom d’atelier / signature',
                      ),
                      const SizedBox(height: 12),
                      _BloomArtTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 12),
                      _BloomArtTextField(
                        controller: _phoneController,
                        label: 'Téléphone',
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 12),
                      _BloomArtTextField(
                        controller: _projectNoteController,
                        label: 'Votre projet artistique',
                        maxLines: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _GuideSummaryCard(guide: guide),
                  const SizedBox(height: 12),
                  _StatusWarningsCard(items: guide.statusWarnings),
                  const SizedBox(height: 12),
                  _Plan30Card(items: guide.plan30),
                  const SizedBox(height: 12),
                  _AidesCard(items: guide.aides),
                  const SizedBox(height: 18),
                  BloomArtCtaButton(
                    label: _saving
                        ? 'Enregistrement...'
                        : 'Enregistrer mon guide de création',
                    icon: Icons.save_outlined,
                    onPressed: _saving ? null : _saveGuideProgress,
                  ),
                  const SizedBox(height: 12),
                  BloomArtCtaButton(
                    label: 'J’ai mon SIRET : vérifier mon compte vendeur',
                    icon: Icons.verified_user_outlined,
                    onPressed: _saving
                        ? null
                        : () => _saveGuideProgress(goToSiret: true),
                  ),
                ],
              ),
            ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Champ requis';
    return null;
  }

  String? _emailValidator(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) return 'Champ requis';
    if (!normalized.contains('@') || !normalized.contains('.')) {
      return 'Email invalide';
    }
    return null;
  }
}

class _LaunchGuide {
  const _LaunchGuide({
    required this.recommendation,
    required this.blockingAlerts,
    required this.aides,
    required this.plan30,
    required this.summary,
    required this.recommendedLegalStatus,
    required this.statusWarnings,
    required this.steps,
    required this.canStartSiretNow,
  });

  final Map<String, dynamic> recommendation;
  final List<String> blockingAlerts;
  final List<Map<String, dynamic>> aides;
  final List<Map<String, dynamic>> plan30;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> recommendedLegalStatus;
  final List<Map<String, dynamic>> statusWarnings;
  final List<Map<String, dynamic>> steps;
  final bool canStartSiretNow;

  factory _LaunchGuide.forSelection({
    required String region,
    required String status,
    required String creationType,
    required String projectNote,
  }) {
    final activityLabel = BloomArtCreationType.labelOf(creationType);
    final isDrom = <String>{'Guadeloupe', 'Martinique', 'Guyane', 'La Réunion', 'Mayotte'}.contains(region);
    final warnings = <Map<String, dynamic>>[];
    final blocking = <String>[];
    var recommendedStatus = 'Micro-entreprise artisanale';
    var headline = 'Créer une activité artisanale simple, obtenir un SIRET, puis vérifier le compte Bloom Art.';
    var canStartSiretNow = true;

    switch (status) {
      case 'Fonctionnaire':
        recommendedStatus = 'Micro-entreprise avec autorisation préalable / cumul d’activité';
        headline = 'Demander l’autorisation de cumul avant toute vente régulière.';
        canStartSiretNow = false;
        warnings.addAll(<Map<String, dynamic>>[
          _warning('Autorisation employeur obligatoire', 'Avant d’ouvrir une activité régulière, l’agent public doit vérifier le cumul d’activité avec son administration.'),
          _warning('Vente ponctuelle vs activité habituelle', 'Bloom Art doit rester bloqué tant que le statut de vendeur déclaré n’est pas clarifié.'),
        ]);
        blocking.add('Cumul d’activité à valider avant demande SIRET.');
        break;
      case 'Demandeur d’emploi':
        recommendedStatus = 'Micro-entreprise + vérification ACRE / maintien ARE';
        headline = 'Créer le statut tout en vérifiant l’impact sur les droits France Travail.';
        warnings.add(_warning('Déclarer les revenus', 'Les ventes Bloom Art devront être déclarées pour éviter un trop-perçu.'));
        break;
      case 'Étudiant':
        recommendedStatus = 'Micro-entreprise légère ou artiste-auteur selon la nature des œuvres';
        headline = 'Démarrer petit, vérifier bourse/aides et séparer revenus personnels et activité.';
        warnings.add(_warning('Impact aides étudiantes', 'Vérifier l’effet des revenus sur bourse, logement ou rattachement fiscal.'));
        break;
      case 'Indépendant':
        recommendedStatus = 'Ajout / extension d’activité artisan d’art';
        headline = 'Ajouter l’activité artistique au SIRET existant ou créer une activité secondaire adaptée.';
        warnings.add(_warning('Cohérence code APE / activité', 'Le SIRET existant doit couvrir la vente d’œuvres ou être mis à jour.'));
        break;
      case 'Retraité':
        recommendedStatus = 'Micro-entreprise avec vérification cumul emploi-retraite';
        headline = 'Vérifier le cumul emploi-retraite puis créer ou réactiver une activité déclarée.';
        warnings.add(_warning('Cumul emploi-retraite', 'Contrôler les règles de cumul selon le régime de retraite avant ventes régulières.'));
        break;
      case 'Sans activité':
      default:
        recommendedStatus = 'Micro-entreprise artisanale';
        headline = 'Créer un statut simple, obtenir un SIRET, puis activer le vendeur Bloom Art.';
        warnings.add(_warning('Déclaration nécessaire', 'La vente régulière d’œuvres nécessite un statut et un SIRET vérifié.'));
    }

    if (isDrom) {
      warnings.add(_warning('Aides locales $region', 'Vérifier les aides régionales, CMA/CCI, BGE et dispositifs Outre-mer disponibles.'));
    }

    final plan = <Map<String, dynamic>>[
      _step(1, 'Clarifier l’activité', 'Confirmer le type de création : $activityLabel, matériaux, mode de production et vente prévue dans Bloom Art.'),
      _step(2, 'Valider le statut', headline),
      _step(3, 'Préparer les pièces', 'Identité, justificatif d’adresse, coordonnées, RIB, description d’activité, photos d’œuvres et prix de référence privés.'),
      _step(4, 'Créer / mettre à jour le SIRET', 'Passer par le guichet unique, CMA/CCI ou organisme compétent selon le statut conseillé.'),
      _step(5, 'Revenir dans Bloom Art', 'Saisir le SIRET dans le parcours Artisan d’art déclaré pour préremplir ville, CP, région et activer le dashboard vendeur.'),
    ];

    return _LaunchGuide(
      recommendation: <String, dynamic>{
        'title': recommendedStatus,
        'description': headline,
        'priority': canStartSiretNow ? 'standard' : 'blocked_before_authorization',
      },
      blockingAlerts: blocking,
      aides: <Map<String, dynamic>>[
        _aid('CMA / Chambre de Métiers', 'Accompagnement artisanat d’art, immatriculation, formalités et ateliers locaux.'),
        _aid('CCI / BGE', 'Aide au choix du statut, business model, premiers prix et démarches de création.'),
        if (status == 'Demandeur d’emploi') _aid('France Travail', 'Vérifier ACRE, maintien ARE, déclaration mensuelle et accompagnement création.'),
        if (isDrom) _aid('Dispositifs locaux $region', 'Contrôler aides régionales, collectivités et dispositifs Outre-mer.'),
      ],
      plan30: plan,
      summary: <String, dynamic>{
        'region': region,
        'status': status,
        'activity': activityLabel,
        'projectNote': projectNote.trim(),
        'canSellNow': false,
        'nextRequiredAction': canStartSiretNow ? 'Obtenir un SIRET' : 'Obtenir une autorisation préalable',
      },
      recommendedLegalStatus: <String, dynamic>{
        'label': recommendedStatus,
        'why': headline,
        'siretRequired': true,
      },
      statusWarnings: warnings,
      steps: plan,
      canStartSiretNow: canStartSiretNow,
    );
  }

  static Map<String, dynamic> _warning(String title, String body) => <String, dynamic>{
        'title': title,
        'body': body,
      };

  static Map<String, dynamic> _step(int index, String title, String body) => <String, dynamic>{
        'index': index,
        'title': title,
        'body': body,
        'status': index == 1 ? 'current' : 'todo',
      };

  static Map<String, dynamic> _aid(String title, String body) => <String, dynamic>{
        'title': title,
        'body': body,
      };
}

class _BloomArtLaunchHero extends StatelessWidget {
  const _BloomArtLaunchHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9DED1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Guide création d’entreprise',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'Inspiré du parcours personnalisé iliprestō : région, activité et statut servent à générer le guide avant activation du vendeur Bloom Art. Aucune œuvre ne peut être déposée tant que le SIRET n’est pas vérifié.',
            style: TextStyle(color: Color(0xFF6A645E), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9DED1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6A645E), height: 1.45)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _GuideSummaryCard extends StatelessWidget {
  const _GuideSummaryCard({required this.guide});

  final _LaunchGuide guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EEE5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Recommandation de statut', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            guide.recommendedLegalStatus['label'].toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            guide.recommendedLegalStatus['why'].toString(),
            style: const TextStyle(color: Color(0xFF6A645E), height: 1.45),
          ),
          if (guide.blockingAlerts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ...guide.blockingAlerts.map(
              (alert) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(alert, style: const TextStyle(color: Color(0xFF7C2D12)))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusWarningsCard extends StatelessWidget {
  const _StatusWarningsCard({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return _GuideListCard(
      title: 'Points de vigilance',
      icon: Icons.info_outline_rounded,
      items: items,
    );
  }
}

class _Plan30Card extends StatelessWidget {
  const _Plan30Card({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return _GuideListCard(
      title: 'Plan de création du statut',
      icon: Icons.route_outlined,
      items: items,
      numbered: true,
    );
  }
}

class _AidesCard extends StatelessWidget {
  const _AidesCard({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return _GuideListCard(
      title: 'Aides et contacts à vérifier',
      icon: Icons.volunteer_activism_outlined,
      items: items,
    );
  }
}

class _GuideListCard extends StatelessWidget {
  const _GuideListCard({
    required this.title,
    required this.icon,
    required this.items,
    this.numbered = false,
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9DED1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: const Color(0xFF1A1A1A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final index = item['index'];
            final prefix = numbered && index != null ? '$index. ' : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$prefix${item['title'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (item['body'] ?? '').toString(),
                    style: const TextStyle(color: Color(0xFF6A645E), height: 1.4),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BloomArtTextField extends StatelessWidget {
  const _BloomArtTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
