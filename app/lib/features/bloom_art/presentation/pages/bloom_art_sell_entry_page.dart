import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_cta_button.dart';
import '../widgets/seller_profile_choice_card.dart';
import 'bloom_art_artist_creator_form_page.dart';
import 'bloom_art_je_me_lance_form_page.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedType != null &&
        widget.initialSelectedType!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleChoice(widget.initialSelectedType!.trim());
      });
    }
  }

  Future<void> _handleChoice(String profileType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pushNamed('/login');
      }
      return;
    }

    setState(() {
      _redirecting = true;
    });

    try {
      final existingProfile = await _repository.getSellerProfile(user.uid);
      final canCreateDirectly = existingProfile != null &&
          existingProfile.profileType == profileType &&
          (profileType == 'je_me_lance' ||
              existingProfile.stripeAccountLinked ||
              existingProfile.payoutStatus == 'ready' ||
              existingProfile.payoutStatus == 'active' ||
              existingProfile.payoutStatus == 'validated');

      if (canCreateDirectly) {
        if (!mounted) return;
        Navigator.of(context).pushNamed(
          '/bloom-art/create',
          arguments: <String, dynamic>{'profileType': profileType},
        );
        return;
      }

      if (!mounted) return;

      if (profileType == 'artist_creator') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BloomArtArtistCreatorFormPage(),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BloomArtJeMeLanceFormPage(),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _redirecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF7),
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
                        'Connectez-vous pour déposer une création dans Bloom Art.',
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
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE9DED1)),
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
                              'Choisissez votre profil vendeur',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Le parcours ajuste ensuite le niveau de collecte d’informations avant le dépôt de votre création.',
                              style: TextStyle(
                                color: Color(0xFF6A645E),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SellerProfileChoiceCard(
                        title: 'Artiste créateur',
                        subtitle:
                            'Vous disposez déjà d’un statut professionnel ou d’un compte d’encaissement prêt.',
                        icon: Icons.palette_outlined,
                        onTap: () => _handleChoice('artist_creator'),
                      ),
                      const SizedBox(height: 12),
                      SellerProfileChoiceCard(
                        title: 'Je me lance',
                        subtitle:
                            'Vous démarrez la vente d’une pièce unique et devez compléter votre profil avant publication.',
                        icon: Icons.auto_awesome_outlined,
                        onTap: () => _handleChoice('je_me_lance'),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7EEE5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Une fois le profil validé, vous pourrez déposer des photos, définir le prix de référence privé, publier la fiche publique et recevoir des offres connectées au checkout Stripe existant.',
                          style: TextStyle(
                            color: Color(0xFF6A645E),
                            height: 1.45,
                          ),
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