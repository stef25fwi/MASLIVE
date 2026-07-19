import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_cta_button.dart';
import '../widgets/seller_profile_choice_card.dart';
import 'bloom_art_artist_creator_form_page.dart';
import 'bloom_art_je_me_lance_form_page.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

class BloomArtSellEntryPage extends StatefulWidget {
  const BloomArtSellEntryPage({
    super.key,
    this.initialSelectedType,
  });

  final String? initialSelectedType;

  @override
  State<BloomArtSellEntryPage> createState() => _BloomArtSellEntryPageState();
}

class _BloomArtSellEntryPageState extends State<BloomArtSellEntryPage> {
  final BloomArtRepository _repository = BloomArtRepository();
  bool _redirecting = false;

  static const String _artisanArtType = 'artisan_art';
  static const String _legacyArtistCreatorType = 'artist_creator';
  static const String _launchType = 'je_me_lance';

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedType != null &&
        widget.initialSelectedType!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleChoice(_normalizeProfileType(widget.initialSelectedType!.trim()));
      });
    }
  }

  String _normalizeProfileType(String profileType) {
    return profileType == _legacyArtistCreatorType ? _artisanArtType : profileType;
  }

  bool _isArtisanArt(String profileType) {
    return profileType == _artisanArtType || profileType == _legacyArtistCreatorType;
  }

  Future<void> _handleChoice(String profileType) async {
    final normalizedType = _normalizeProfileType(profileType);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pushNamed('/login');
      return;
    }

    setState(() => _redirecting = true);

    try {
      final existingProfile = await _repository.getSellerProfile(user.uid);
      if (!mounted) return;

      if (existingProfile?.canSell == true && _isArtisanArt(normalizedType)) {
        Navigator.of(context).pushReplacementNamed('/bloom-art/dashboard');
        return;
      }

      if (normalizedType == _launchType) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BloomArtJeMeLanceFormPage(),
          ),
        );
        return;
      }

      if (_isArtisanArt(normalizedType)) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BloomArtArtistCreatorFormPage(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _redirecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: MasliveTokens.surface,
      appBar: AppBar(
        backgroundColor: MasliveTokens.surface,
        elevation: 0,
        title: const Text(
          'Vendre dans Bloom Art',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: user == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Connectez-vous pour ouvrir votre espace vendeur Bloom Art.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      BloomArtCtaButton(
                        label: 'Se connecter',
                        icon: Icons.login_rounded,
                        onPressed: () => Navigator.of(context).pushNamed('/login'),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: <Widget>[
                  ListView(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 28),
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: MasliveTokens.line),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 24,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Choisissez votre parcours vendeur',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Bloom Art distingue les artistes déjà déclarés des créateurs qui doivent encore obtenir leur SIRET. Le dépôt d’œuvre est réservé aux comptes vérifiés.',
                              style: TextStyle(color: MasliveTokens.textMuted, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SellerProfileChoiceCard(
                        title: 'Artisan d’art déclaré',
                        subtitle:
                            'J’ai un SIRET : vérifier mon activité, créer ma galerie et accéder au dashboard Bloom Art.',
                        icon: Icons.verified_rounded,
                        onTap: () => _handleChoice(_artisanArtType),
                      ),
                      const SizedBox(height: 12),
                      SellerProfileChoiceCard(
                        title: 'Je me lance',
                        subtitle:
                            'Je n’ai pas encore de SIRET : suivre le guide de création d’entreprise avant de vendre.',
                        icon: Icons.auto_awesome_outlined,
                        onTap: () => _handleChoice(_launchType),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: MasliveTokens.bg,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Une fois le SIRET vérifié, vous pourrez gérer votre galerie, déposer des photos, définir le prix de référence privé, publier vos fiches et recevoir des offres.',
                          style: TextStyle(color: MasliveTokens.textMuted, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                  if (_redirecting)
                    Container(
                      color: Colors.black.withValues(alpha: 0.08),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
      ),
    );
  }
}
