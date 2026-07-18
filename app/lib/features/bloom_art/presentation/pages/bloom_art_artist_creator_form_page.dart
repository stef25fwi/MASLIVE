import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../services/french_geo_lookup_service.dart';
import '../../data/models/bloom_art_seller_profile.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../../services/bloom_art_business_verification_service.dart';
import '../widgets/bloom_art_cta_button.dart';

class BloomArtArtistCreatorFormPage extends StatefulWidget {
  const BloomArtArtistCreatorFormPage({super.key});

  @override
  State<BloomArtArtistCreatorFormPage> createState() =>
      _BloomArtArtistCreatorFormPageState();
}

class _BloomArtArtistCreatorFormPageState
    extends State<BloomArtArtistCreatorFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final BloomArtRepository _repository = BloomArtRepository();
  final BloomArtBusinessVerificationService _verificationService =
      const BloomArtBusinessVerificationService();
  final FrenchGeoLookupService _geoLookupService = const FrenchGeoLookupService();
  Timer? _postalCodeDebounce;
  String _lastLookedUpPostalCode = '';

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _artistNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _siretController = TextEditingController();
  final TextEditingController _sirenController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _nafCodeController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _verifyingSiret = false;
  bool _stripeAccountLinked = false;
  String _payoutStatus = 'pending';
  String _creationType = BloomArtCreationType.artisanatArt;
  String _businessVerificationStatus = 'not_verified';
  DateTime? _businessVerifiedAt;
  BloomArtBusinessVerificationResult? _verificationResult;

  bool get _businessVerified =>
      _businessVerificationStatus == 'verified' &&
      _siretController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _postalCodeController.addListener(_onPostalCodeChanged);
  }

  @override
  void dispose() {
    _postalCodeDebounce?.cancel();
    _postalCodeController.removeListener(_onPostalCodeChanged);
    _fullNameController.dispose();
    _artistNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _regionController.dispose();
    _countryController.dispose();
    _siretController.dispose();
    _sirenController.dispose();
    _businessNameController.dispose();
    _nafCodeController.dispose();
    super.dispose();
  }

  void _onPostalCodeChanged() {
    final postalCode = _postalCodeController.text.trim();
    _postalCodeDebounce?.cancel();
    if (!_geoLookupService.isValidPostalCode(postalCode) ||
        postalCode == _lastLookedUpPostalCode) {
      return;
    }
    _postalCodeDebounce = Timer(const Duration(milliseconds: 400), () {
      _autoFillCityAndRegionFromPostalCode(postalCode);
    });
  }

  Future<void> _autoFillCityAndRegionFromPostalCode(String postalCode) async {
    _lastLookedUpPostalCode = postalCode;
    final match = await _geoLookupService.lookupByPostalCode(
      postalCode,
      preferredCity: _cityController.text,
    );
    if (!mounted || match.isEmpty) return;

    if (match.city.isNotEmpty && _cityController.text.trim().isEmpty) {
      _cityController.text = match.city;
    }
    if (match.region.isNotEmpty && _regionController.text.trim().isEmpty) {
      _regionController.text = match.region;
    }
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
    _countryController.text = 'France';

    final profile = await _repository.getSellerProfile(user.uid);
    if (!mounted) return;

    if (profile != null) {
      _fullNameController.text = profile.fullName;
      _artistNameController.text = profile.artistName;
      _emailController.text = profile.email;
      _phoneController.text = profile.phone;
      _bioController.text = profile.bio;
      _addressController.text = profile.businessAddress.trim().isNotEmpty
          ? profile.businessAddress
          : profile.address;
      _cityController.text = profile.city;
      _postalCodeController.text = profile.postalCode;
      _regionController.text = profile.region;
      _countryController.text = profile.country.trim().isEmpty ? 'France' : profile.country;
      _siretController.text = profile.siret;
      _sirenController.text = profile.siren;
      _businessNameController.text = profile.businessName;
      _nafCodeController.text = profile.nafCode;
      _creationType = BloomArtCreationType.normalize(profile.creationType);
      _stripeAccountLinked = profile.stripeAccountLinked;
      _payoutStatus = profile.payoutStatus.trim().isEmpty
          ? 'pending'
          : profile.payoutStatus;
      _businessVerificationStatus = profile.businessVerificationStatus;
      _businessVerifiedAt = profile.businessVerifiedAt;
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _verifySiret() async {
    final siret = _siretController.text.trim();
    setState(() {
      _verifyingSiret = true;
    });

    try {
      // Vérification effectuée côté serveur (Cloud Function verifyBloomArtSiret) :
      // le client ne peut plus s'auto-déclarer "verified"/"active" directement,
      // seul le backend (Admin SDK, après appel réel à l'API gouv) pose ces
      // champs sur bloom_art_seller_profiles.
      final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
          .httpsCallable('verifyBloomArtSiret');
      final response = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{'siret': siret},
      );
      final data = response.data;
      if (!mounted) return;

      final result = BloomArtBusinessVerificationResult(
        siret: (data['siret'] ?? '').toString(),
        siren: (data['siren'] ?? '').toString(),
        denomination: (data['denomination'] ?? '').toString(),
        nafCode: (data['nafCode'] ?? '').toString(),
        address: (data['address'] ?? '').toString(),
        postalCode: (data['postalCode'] ?? '').toString(),
        city: (data['city'] ?? '').toString(),
        region: (data['region'] ?? '').toString(),
        isValid: data['isValid'] == true,
        errorMessage: data['errorMessage']?.toString(),
      );

      if (!result.isValid) {
        setState(() {
          _verificationResult = result;
          _businessVerificationStatus = 'rejected';
          _businessVerifiedAt = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'SIRET invalide ou introuvable.'),
          ),
        );
        return;
      }

      setState(() {
        _verificationResult = result;
        _siretController.text = result.siret;
        _sirenController.text = result.siren;
        _businessNameController.text = result.denomination;
        _nafCodeController.text = result.nafCode;
        if (result.address.trim().isNotEmpty) {
          _addressController.text = result.address;
        }
        if (result.postalCode.trim().isNotEmpty) {
          _postalCodeController.text = result.postalCode;
        }
        if (result.city.trim().isNotEmpty) {
          _cityController.text = result.city;
        }
        if (result.region.trim().isNotEmpty) {
          _regionController.text = result.region;
        }
        if (_countryController.text.trim().isEmpty) {
          _countryController.text = 'France';
        }
        _businessVerificationStatus = 'verified';
        _businessVerifiedAt = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SIRET vérifié. Les informations vendeur sont préremplies.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _businessVerificationStatus = 'error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vérification SIRET impossible : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _verifyingSiret = false;
        });
      }
    }
  }

  void _resetSiretVerification(String _) {
    if (_businessVerificationStatus == 'not_verified') return;
    setState(() {
      _verificationResult = null;
      _businessVerificationStatus = 'not_verified';
      _businessVerifiedAt = null;
      _sirenController.clear();
      _businessNameController.clear();
      _nafCodeController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_businessVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vérifiez votre SIRET avant de créer l’espace vendeur Bloom Art.'),
        ),
      );
      return;
    }

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
      // N'écrit que les champs de profil éditables : sellerStatus, siret,
      // businessVerificationStatus, stripe, etc. ont déjà été posés côté
      // serveur par verifyBloomArtSiret et sont bloqués côté rules pour le
      // client (voir firestore.rules match /bloom_art_seller_profiles).
      await _repository.updateSellerProfileEditableFields(
        userId: user.uid,
        creationType: _creationType,
        fullName: _fullNameController.text.trim(),
        artistName: _artistNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        region: _regionController.text.trim(),
        country: _countryController.text.trim().isEmpty ? 'France' : _countryController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/bloom-art/dashboard');
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
          'Artisan d’art déclaré',
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
                  const _BloomArtFormHero(
                    title: 'Créez votre galerie Bloom Art',
                    subtitle:
                        'Vérifiez votre SIRET, préremplissez vos informations officielles, puis accédez à votre dashboard pour déposer vos œuvres et recevoir des offres.',
                  ),
                  const SizedBox(height: 18),
                  _BloomArtTextField(
                    controller: _siretController,
                    label: 'SIRET de l’activité artistique',
                    keyboardType: TextInputType.number,
                    validator: _siretValidator,
                    onChanged: _resetSiretVerification,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: BloomArtCtaButton(
                          label: _verifyingSiret ? 'Vérification...' : 'Vérifier mon SIRET',
                          icon: Icons.verified_outlined,
                          onPressed: _verifyingSiret ? null : _verifySiret,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _BusinessVerificationCard(
                    status: _businessVerificationStatus,
                    result: _verificationResult,
                    verifiedAt: _businessVerifiedAt,
                  ),
                  const SizedBox(height: 18),
                  _BloomArtTextField(
                    controller: _businessNameController,
                    label: 'Dénomination officielle',
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _BloomArtTextField(
                          controller: _sirenController,
                          label: 'SIREN',
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BloomArtTextField(
                          controller: _nafCodeController,
                          label: 'Code APE / NAF',
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _BloomArtTextField(
                    controller: _fullNameController,
                    label: 'Nom complet',
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  _BloomArtTextField(
                    controller: _artistNameController,
                    label: 'Nom d’artiste / atelier',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _creationType,
                    decoration: const InputDecoration(
                      labelText: 'Type de création',
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
                    controller: _addressController,
                    label: 'Adresse officielle',
                    maxLines: 2,
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _BloomArtTextField(
                          controller: _postalCodeController,
                          label: 'Code postal',
                          validator: _requiredValidator,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BloomArtTextField(
                          controller: _cityController,
                          label: 'Ville',
                          validator: _requiredValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _BloomArtTextField(
                          controller: _regionController,
                          label: 'Région',
                          validator: _requiredValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BloomArtTextField(
                          controller: _countryController,
                          label: 'Pays',
                          validator: _requiredValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _BloomArtTextField(
                    controller: _bioController,
                    label: 'Bio / démarche artistique',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3EF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _stripeAccountLinked
                          ? 'Compte de paiement Stripe relié (statut : $_payoutStatus). Gérez-le depuis votre dashboard vendeur.'
                          : 'Aucun compte de paiement relié pour l’instant. Vous pourrez le configurer depuis votre dashboard vendeur après création.',
                      style: const TextStyle(color: Color(0xFF6A645E), height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  BloomArtCtaButton(
                    label: _saving
                        ? 'Création du dashboard...'
                        : 'Créer mon dashboard Bloom Art',
                    icon: Icons.dashboard_customize_outlined,
                    onPressed: _saving || !_businessVerified ? null : _submit,
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

  String? _siretValidator(String? value) {
    final clean = _verificationService.normalizeSiret(value ?? '');
    if (clean.isEmpty) return 'SIRET requis';
    if (clean.length != 14) return 'Le SIRET doit contenir 14 chiffres';
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

class _BusinessVerificationCard extends StatelessWidget {
  const _BusinessVerificationCard({
    required this.status,
    required this.result,
    required this.verifiedAt,
  });

  final String status;
  final BloomArtBusinessVerificationResult? result;
  final DateTime? verifiedAt;

  @override
  Widget build(BuildContext context) {
    final verified = status == 'verified';
    final rejected = status == 'rejected' || status == 'error';
    final title = verified
        ? 'SIRET vérifié'
        : rejected
            ? 'SIRET non validé'
            : 'Vérification SIRET requise';
    final body = verified
        ? '${result?.denomination ?? 'Entreprise validée'}${verifiedAt == null ? '' : ' · vérifié aujourd’hui'}'
        : rejected
            ? result?.errorMessage ?? 'La vérification n’a pas abouti.'
            : 'Le dépôt d’œuvre est bloqué tant que le SIRET n’est pas vérifié.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: verified ? const Color(0xFFEAF7EE) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: verified ? const Color(0xFFB7E1C1) : const Color(0xFFEBD1A7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            verified ? Icons.verified_rounded : Icons.info_outline_rounded,
            color: verified ? const Color(0xFF217A3B) : const Color(0xFF9A6A18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: Color(0xFF6A645E), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BloomArtFormHero extends StatelessWidget {
  const _BloomArtFormHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9DED1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6A645E), height: 1.45),
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
    this.onChanged,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF7F3EF) : Colors.white,
      ),
    );
  }
}
