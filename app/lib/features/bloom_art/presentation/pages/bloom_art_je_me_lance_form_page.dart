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
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _projectNoteController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _activityChosen = false;
  bool _statusUnderstood = false;
  bool _formalitiesStarted = false;
  String _creationType = BloomArtCreationType.artisanatArt;
  DateTime? _createdAt;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _artistNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _projectNoteController.dispose();
    super.dispose();
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
      _createdAt = profile.createdAt;
      _fullNameController.text = profile.fullName;
      _artistNameController.text = profile.artistName;
      _emailController.text = profile.email;
      _phoneController.text = profile.phone;
      _cityController.text = profile.city;
      _regionController.text = profile.region;
      _projectNoteController.text = profile.bio;
      _creationType = BloomArtCreationType.normalize(profile.creationType);
      _activityChosen = profile.creationType.trim().isNotEmpty;
      _statusUnderstood = profile.businessVerificationStatus != 'missing_siret';
      _formalitiesStarted = profile.sellerStatus == 'launch_guide_started' ||
          profile.sellerStatus == 'launch_guide_ready';
    }

    setState(() => _loading = false);
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
        city: _cityController.text.trim(),
        postalCode: '',
        region: _regionController.text.trim(),
        country: 'France',
        payoutStatus: 'pending',
        stripeAccountLinked: false,
        sellerStatus: _formalitiesStarted ? 'launch_guide_started' : 'launch_guide',
        businessVerificationStatus: 'missing_siret',
        businessVerificationSource: 'bloom_art_launch_guide',
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
        SnackBar(content: Text('Impossible d\'enregistrer le parcours : $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  DropdownButtonFormField<String>(
                    initialValue: _creationType,
                    decoration: const InputDecoration(
                      labelText: 'Type de création envisagé',
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
                        _activityChosen = true;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
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
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _BloomArtTextField(
                          controller: _cityController,
                          label: 'Ville',
                          validator: _requiredValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BloomArtTextField(
                          controller: _regionController,
                          label: 'Région',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _BloomArtTextField(
                    controller: _projectNoteController,
                    label: 'Votre projet artistique',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 18),
                  _LaunchChecklistCard(
                    activityChosen: _activityChosen,
                    statusUnderstood: _statusUnderstood,
                    formalitiesStarted: _formalitiesStarted,
                    onActivityChanged: (value) => setState(() => _activityChosen = value),
                    onStatusChanged: (value) => setState(() => _statusUnderstood = value),
                    onFormalitiesChanged: (value) => setState(() => _formalitiesStarted = value),
                  ),
                  const SizedBox(height: 18),
                  _LaunchAdviceCard(creationType: _creationType),
                  const SizedBox(height: 18),
                  BloomArtCtaButton(
                    label: _saving
                        ? 'Enregistrement...'
                        : 'Enregistrer mon parcours de lancement',
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
            'Ce parcours vous prépare à vendre dans Bloom Art. Il ne permet pas encore de déposer une œuvre : la vente sera activée uniquement après obtention et vérification du SIRET.',
            style: TextStyle(color: Color(0xFF6A645E), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _LaunchChecklistCard extends StatelessWidget {
  const _LaunchChecklistCard({
    required this.activityChosen,
    required this.statusUnderstood,
    required this.formalitiesStarted,
    required this.onActivityChanged,
    required this.onStatusChanged,
    required this.onFormalitiesChanged,
  });

  final bool activityChosen;
  final bool statusUnderstood;
  final bool formalitiesStarted;
  final ValueChanged<bool> onActivityChanged;
  final ValueChanged<bool> onStatusChanged;
  final ValueChanged<bool> onFormalitiesChanged;

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
          const Text(
            'Checklist avant vente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          CheckboxListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: activityChosen,
            title: const Text('J’ai choisi mon type de création'),
            onChanged: (value) => onActivityChanged(value ?? false),
          ),
          CheckboxListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: statusUnderstood,
            title: const Text('Je comprends qu’un SIRET est requis pour vendre'),
            subtitle: const Text('Micro-entreprise, artiste-auteur, artisan ou structure adaptée.'),
            onChanged: (value) => onStatusChanged(value ?? false),
          ),
          CheckboxListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: formalitiesStarted,
            title: const Text('J’ai commencé mes démarches administratives'),
            subtitle: const Text('Préparer identité, adresse, activité, RIB et pièces justificatives.'),
            onChanged: (value) => onFormalitiesChanged(value ?? false),
          ),
        ],
      ),
    );
  }
}

class _LaunchAdviceCard extends StatelessWidget {
  const _LaunchAdviceCard({required this.creationType});

  final String creationType;

  @override
  Widget build(BuildContext context) {
    final label = BloomArtCreationType.labelOf(creationType);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EEE5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        'Parcours conseillé pour $label : commencez par clarifier votre statut, obtenez un SIRET, puis revenez dans Bloom Art pour vérifier votre compte Artisan d’art déclaré. Le dépôt d’œuvre restera bloqué tant que ce contrôle n’est pas validé.',
        style: const TextStyle(color: Color(0xFF6A645E), height: 1.45),
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
