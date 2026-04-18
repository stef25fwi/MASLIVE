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
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
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
    _bioController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
      _bioController.text = profile.bio;
      _addressController.text = profile.address;
      _cityController.text = profile.city;
      _countryController.text = profile.country;
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pushNamed('/login');
      }
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final profile = BloomArtSellerProfile(
        id: user.uid,
        userId: user.uid,
        profileType: 'je_me_lance',
        fullName: _fullNameController.text.trim(),
        artistName: _artistNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        payoutStatus: 'pending',
        stripeAccountLinked: false,
        createdAt: _createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.saveSellerProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/bloom-art/create',
        arguments: <String, dynamic>{'profileType': 'je_me_lance'},
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'enregistrer le profil : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
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
          'Profil je me lance',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: <Widget>[
                  const _BloomArtLaunchHero(),
                  const SizedBox(height: 18),
                  _BloomArtTextField(
                    controller: _fullNameController,
                    label: 'Nom complet',
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  _BloomArtTextField(
                    controller: _artistNameController,
                    label: 'Nom d\'atelier / signature (optionnel)',
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
                    label: 'Telephone',
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  _BloomArtTextField(
                    controller: _cityController,
                    label: 'Ville',
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  _BloomArtTextField(
                    controller: _countryController,
                    label: 'Pays',
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  _BloomArtTextField(
                    controller: _addressController,
                    label: 'Adresse',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _BloomArtTextField(
                    controller: _bioController,
                    label: 'Parlez de votre creation',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EEE5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Le statut vendeur reste en attente tant que votre configuration de paiement n\'est pas finalisee dans votre backend existant.',
                      style: TextStyle(color: Color(0xFF6A645E), height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 18),
                  BloomArtCtaButton(
                    label: _saving
                        ? 'Enregistrement en cours...'
                        : 'Continuer vers le depot de la creation',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Champ requis';
    }
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
            'Vous vous lancez ?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'Commencez par un profil simple, puis deposez votre piece Bloom Art. Le prix reste prive, les visiteurs ne voient que l\'oeuvre et proposent un montant.',
            style: TextStyle(color: Color(0xFF6A645E), height: 1.45),
          ),
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