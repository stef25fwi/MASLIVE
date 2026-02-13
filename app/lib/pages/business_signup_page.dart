import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/country_flag.dart';

class BusinessSignupPage extends StatefulWidget {
  const BusinessSignupPage({super.key});

  @override
  State<BusinessSignupPage> createState() => _BusinessSignupPageState();
}

class _BusinessSignupPageState extends State<BusinessSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  // Dropdowns
  String? _legalForm;
  String? _country;
  String? _region;
  String? _activitySector;

  // Formes juridiques françaises
  final List<String> _legalForms = [
    'SARL - Société à Responsabilité Limitée',
    'SAS - Société par Actions Simplifiée',
    'SASU - Société par Actions Simplifiée Unipersonnelle',
    'EURL - Entreprise Unipersonnelle à Responsabilité Limitée',
    'SA - Société Anonyme',
    'SNC - Société en Nom Collectif',
    'SCS - Société en Commandite Simple',
    'Auto-entrepreneur / Micro-entreprise',
    'EI - Entreprise Individuelle',
    'EIRL - Entreprise Individuelle à Responsabilité Limitée',
    'Association loi 1901',
    'Autre',
  ];

  final List<String> _countries = [
    'France',
    'Guadeloupe',
    'Martinique',
    'Guyane',
    'Réunion',
    'Mayotte',
    'Autre',
  ];

  final List<String> _regions = [
    'Auvergne-Rhône-Alpes',
    'Bourgogne-Franche-Comté',
    'Bretagne',
    'Centre-Val de Loire',
    'Corse',
    'Grand Est',
    'Guadeloupe',
    'Guyane',
    'Hauts-de-France',
    'Île-de-France',
    'Martinique',
    'Mayotte',
    'Normandie',
    'Nouvelle-Aquitaine',
    'Occitanie',
    'Pays de la Loire',
    'Provence-Alpes-Côte d\'Azur',
    'Réunion',
  ];

  final List<String> _sectors = [
    'Arts et spectacles',
    'Commerce',
    'Communication et multimédia',
    'Construction et BTP',
    'Éducation et formation',
    'Finance et assurance',
    'Hôtellerie et restauration',
    'Immobilier',
    'Industrie manufacturière',
    'Informatique et télécommunications',
    'Santé et action sociale',
    'Services aux entreprises',
    'Services aux particuliers',
    'Transport et logistique',
    'Tourisme et loisirs',
    'Autre',
  ];



  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _companyNameCtrl.dispose();
    _siretCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _postalCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Créer le compte utilisateur
      final cred = await AuthService.instance.createUserWithEmailPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        throw Exception('Impossible de récupérer l\'utilisateur créé');
      }

      // 2. Enregistrer les données entreprise dans Firestore
      final businessRef = _db.collection('businesses').doc(uid);
      final businessSnap = await businessRef.get();
      if (businessSnap.exists) {
        throw Exception('Un profil professionnel existe déjà pour ce compte');
      }

      await businessRef.set({
        'ownerUid': uid,
        'email': _emailCtrl.text.trim(),
        'status': 'pending',
        'companyName': _companyNameCtrl.text.trim(),
        'siret': _siretCtrl.text.trim(),
        'legalForm': _legalForm,
        'activitySector': _activitySector,
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'postalCode': _postalCodeCtrl.text.trim(),
        'region': _region,
        'country': _country,
        'phone': _phoneCtrl.text.trim(),
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Optionnel: enrichir le profil user (autorisé par rules)
      await AuthService.instance.createOrUpdateUserProfile(
        userId: uid,
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        region: _region,
      );

      if (!mounted) return;

      // 3. Rediriger vers le dashboard
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte professionnel créé avec succès !'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushReplacementNamed('/account-ui');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFFFFF);
    const text = Color(0xFF1A1A1A);
    const subText = Color(0xFF6B7280);

    const masliveGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFE08A),
        Color(0xFFFFB067),
        Color(0xFFFF6FAE),
        Color(0xFF9B7BFF),
        Color(0xFF4FD8FF),
      ],
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Créer un compte professionnel',
          style: TextStyle(color: text, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: CustomPaint(painter: _HexPatternPainter()),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Section Authentification
                    _SectionHeader(
                      icon: Icons.lock_outline,
                      title: 'Informations de connexion',
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _emailCtrl,
                      label: 'Email professionnel *',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v?.isEmpty ?? true
                          ? 'Email requis'
                          : !v!.contains('@')
                          ? 'Email invalide'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _passwordCtrl,
                      label: 'Mot de passe *',
                      icon: Icons.lock_outline,
                      obscureText: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? 'Minimum 6 caractères'
                          : null,
                    ),

                    const SizedBox(height: 24),

                    // Section Entreprise
                    _SectionHeader(
                      icon: Icons.business,
                      title: 'Informations entreprise',
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _companyNameCtrl,
                      label: 'Raison sociale *',
                      icon: Icons.business_outlined,
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'Raison sociale requise' : null,
                    ),
                    const SizedBox(height: 12),
                    _DropdownField(
                      label: 'Forme juridique *',
                      value: _legalForm,
                      items: _legalForms,
                      icon: Icons.account_balance_outlined,
                      onChanged: (v) => setState(() => _legalForm = v),
                      validator: (v) =>
                          v == null ? 'Forme juridique requise' : null,
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _siretCtrl,
                      label: 'Numéro SIRET *',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => v?.isEmpty ?? true
                          ? 'SIRET requis'
                          : v!.length != 14
                          ? 'SIRET doit contenir 14 chiffres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _DropdownField(
                      label: 'Secteur d\'activité *',
                      value: _activitySector,
                      items: _sectors,
                      icon: Icons.work_outline,
                      onChanged: (v) => setState(() => _activitySector = v),
                      validator: (v) =>
                          v == null ? 'Secteur d\'activité requis' : null,
                    ),

                    const SizedBox(height: 24),

                    // Section Adresse
                    _SectionHeader(
                      icon: Icons.location_on_outlined,
                      title: 'Adresse du siège social',
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _addressCtrl,
                      label: 'Adresse *',
                      icon: Icons.home_outlined,
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'Adresse requise' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _FormField(
                            controller: _postalCodeCtrl,
                            label: 'Code postal *',
                            icon: Icons.markunread_mailbox_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            validator: (v) => v?.isEmpty ?? true
                                ? 'Code postal requis'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _FormField(
                            controller: _cityCtrl,
                            label: 'Ville *',
                            icon: Icons.location_city_outlined,
                            validator: (v) =>
                                v?.isEmpty ?? true ? 'Ville requise' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DropdownField(
                      label: 'Région *',
                      value: _region,
                      items: _regions,
                      icon: Icons.map_outlined,
                      onChanged: (v) => setState(() => _region = v),
                      validator: (v) => v == null ? 'Région requise' : null,
                    ),
                    const SizedBox(height: 12),
                    _DropdownField(
                      label: 'Pays *',
                      value: _country,
                      items: _countries,
                      icon: Icons.public,
                      itemLabelBuilder: formatCountryNameWithFlag,
                      onChanged: (v) => setState(() => _country = v),
                      validator: (v) => v == null ? 'Pays requis' : null,
                    ),

                    const SizedBox(height: 24),

                    // Section Responsable
                    _SectionHeader(
                      icon: Icons.person_outline,
                      title: 'Responsable légal',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FormField(
                            controller: _firstNameCtrl,
                            label: 'Prénom *',
                            icon: Icons.person_outline,
                            validator: (v) =>
                                v?.isEmpty ?? true ? 'Prénom requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormField(
                            controller: _lastNameCtrl,
                            label: 'Nom *',
                            icon: Icons.person_outline,
                            validator: (v) =>
                                v?.isEmpty ?? true ? 'Nom requis' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _phoneCtrl,
                      label: 'Téléphone professionnel *',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'Téléphone requis' : null,
                    ),

                    const SizedBox(height: 32),

                    // Bouton de soumission
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: masliveGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(38),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Créer mon compte professionnel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      '* Champs obligatoires',
                      style: TextStyle(
                        color: subText,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6FAE), Color(0xFF9B7BFF)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1A111827)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1A111827)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF9B7BFF), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final String Function(String value)? itemLabelBuilder;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
    this.validator,
    this.itemLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1A111827)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1A111827)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF9B7BFF), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            itemLabelBuilder?.call(item) ?? item,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _HexPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9B7BFF).withAlpha(26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const hexSize = 30.0;
    final rows = (size.height / (hexSize * 1.5)).ceil() + 1;
    final cols = (size.width / (hexSize * 1.732)).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final x = col * hexSize * 1.732 + (row.isOdd ? hexSize * 0.866 : 0);
        final y = row * hexSize * 1.5;
        _drawHexagon(canvas, paint, x, y, hexSize);
      }
    }
  }

  void _drawHexagon(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double size,
  ) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * 3.14159 / 180;
      final px = x + size * Math.cos(angle);
      final py = y + size * Math.sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Math {
  static double cos(double radians) => math.cos(radians);
  static double sin(double radians) => math.sin(radians);
}
