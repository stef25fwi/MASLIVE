import 'package:flutter/material.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

/// Page « Informations légales » : Mentions légales + Conditions Générales
/// d'Utilisation (CGU), accessible notamment depuis la page de connexion
/// (« Qui sommes-nous ? »).
///
/// ⚠️ Les champs marqués `[À COMPLÉTER : …]` doivent être renseignés par
/// l'exploitant avec ses informations réelles (raison sociale, SIRET, adresse,
/// contact…). Ils ne peuvent pas être inventés sans engager la responsabilité
/// de l'éditeur.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, this.initialTab = 0});

  /// 0 = Mentions légales, 1 = CGU.
  final int initialTab;

  /// Date de dernière mise à jour affichée en pied de document.
  static const String _lastUpdated = '21 juillet 2026';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        backgroundColor: MasliveTokens.bg,
        appBar: AppBar(
          title: const Text('Informations légales'),
          backgroundColor: Colors.white,
          foregroundColor: MasliveTokens.text,
          elevation: 0,
          bottom: const TabBar(
            labelColor: MasliveTokens.primary,
            unselectedLabelColor: MasliveTokens.textMuted,
            indicatorColor: MasliveTokens.primary,
            tabs: [
              Tab(text: 'Mentions légales'),
              Tab(text: 'CGU'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LegalScroll(sections: _mentionsLegales, lastUpdated: _lastUpdated),
            _LegalScroll(sections: _cgu, lastUpdated: _lastUpdated),
          ],
        ),
      ),
    );
  }
}

/// Un bloc de contenu : titre optionnel + une liste de paragraphes.
///
/// Un paragraphe commençant par « • » est rendu comme une puce.
class _LegalBlock {
  final String? heading;
  final List<String> paragraphs;
  const _LegalBlock({this.heading, this.paragraphs = const []});
}

class _LegalScroll extends StatelessWidget {
  const _LegalScroll({required this.sections, required this.lastUpdated});

  final List<_LegalBlock> sections;
  final String lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          for (final block in sections) _LegalBlockView(block: block),
          const SizedBox(height: 24),
          Divider(color: MasliveTokens.line),
          const SizedBox(height: 8),
          Text(
            'Dernière mise à jour : $lastUpdated.',
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: MasliveTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView({required this.block});
  final _LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final heading = block.heading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heading != null) ...[
          const SizedBox(height: 18),
          Text(
            heading,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MasliveTokens.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (final paragraph in block.paragraphs) _paragraph(paragraph),
      ],
    );
  }

  Widget _paragraph(String text) {
    final isBullet = text.startsWith('• ');
    final body = isBullet ? text.substring(2) : text;
    final content = Padding(
      padding: EdgeInsets.only(bottom: 10, left: isBullet ? 4 : 0),
      child: isBullet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 8),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: MasliveTokens.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(child: _bodyText(body)),
              ],
            )
          : _bodyText(body),
    );
    return content;
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.5,
        color: MasliveTokens.text,
      ),
    );
  }
}

// ===========================================================================
// CONTENU — MENTIONS LÉGALES
// ===========================================================================

const List<_LegalBlock> _mentionsLegales = [
  _LegalBlock(
    paragraphs: [
      'Les présentes mentions légales s\'appliquent au service « MASLIVE » '
          '(ci-après « l\'Application » ou « le Service »), accessible '
          'notamment à l\'adresse https://maslive.web.app ainsi que via ses '
          'applications mobiles. MASLIVE est une plateforme de cartographie '
          'événementielle proposant la géolocalisation et le suivi en direct, '
          'la mise en avant de points d\'intérêt, ainsi que des services de '
          'boutique et de marketplace.',
    ],
  ),
  _LegalBlock(
    heading: '1. Éditeur du Service',
    paragraphs: [
      'Le Service est édité par :',
      '• Raison sociale : [À COMPLÉTER : dénomination sociale de l\'éditeur]',
      '• Forme juridique : [À COMPLÉTER : SAS, SARL, auto-entrepreneur, association…]',
      '• Capital social : [À COMPLÉTER : montant en euros, le cas échéant]',
      '• Siège social : [À COMPLÉTER : adresse postale complète]',
      '• Immatriculation : [À COMPLÉTER : n° SIREN/SIRET et ville du RCS, le cas échéant]',
      '• Numéro de TVA intracommunautaire : [À COMPLÉTER, le cas échéant]',
      '• Adresse e-mail de contact : [À COMPLÉTER : adresse e-mail de contact]',
      '• Téléphone : [À COMPLÉTER, le cas échéant]',
    ],
  ),
  _LegalBlock(
    heading: '2. Directeur de la publication',
    paragraphs: [
      'Le directeur de la publication est [À COMPLÉTER : nom et prénom du '
          'représentant légal ou de la personne désignée], en sa qualité de '
          '[À COMPLÉTER : fonction, ex. gérant, président].',
    ],
  ),
  _LegalBlock(
    heading: '3. Hébergement',
    paragraphs: [
      'L\'Application web et ses données sont hébergées via les services '
          'Google Firebase (Firebase Hosting, Cloud Firestore, Cloud Storage, '
          'Cloud Functions), fournis par :',
      '• Google Ireland Limited, Gordon House, Barrow Street, Dublin 4, '
          'Irlande — pour les utilisateurs de l\'Espace économique européen ;',
      '• et/ou Google LLC, 1600 Amphitheatre Parkway, Mountain View, '
          'CA 94043, États-Unis.',
      'Les infrastructures de traitement sont susceptibles d\'être localisées '
          'dans la région « us-east1 ». Voir la section « Données à caractère '
          'personnel » concernant les transferts hors Union européenne.',
    ],
  ),
  _LegalBlock(
    heading: '4. Propriété intellectuelle',
    paragraphs: [
      'La structure générale de l\'Application, ainsi que les textes, '
          'graphismes, logos, icônes, pictogrammes, la charte graphique, les '
          'bases de données et, plus généralement, l\'ensemble des éléments '
          'composant le Service (à l\'exception des contenus fournis par les '
          'utilisateurs et des services tiers) sont la propriété exclusive de '
          'l\'éditeur ou de ses partenaires et sont protégés par le droit de la '
          'propriété intellectuelle.',
      'Toute reproduction, représentation, modification, publication ou '
          'adaptation de tout ou partie de ces éléments, quel que soit le '
          'moyen ou le procédé utilisé, est interdite sans l\'autorisation '
          'écrite préalable de l\'éditeur, sous réserve des exceptions légales.',
      'La marque « MASLIVE » et son logo sont protégés. Toute utilisation non '
          'autorisée est susceptible de constituer une contrefaçon.',
    ],
  ),
  _LegalBlock(
    heading: '5. Services et technologies tiers',
    paragraphs: [
      'Le Service s\'appuie sur des prestataires tiers, notamment :',
      '• Mapbox (fonds de carte et rendu cartographique) ;',
      '• Google Firebase (authentification, base de données, stockage, '
          'fonctions serveur, notifications) ;',
      '• Stripe (traitement des paiements et abonnements).',
      'Ces prestataires disposent de leurs propres conditions et politiques, '
          'auxquelles l\'utilisateur est susceptible d\'être soumis pour les '
          'fonctionnalités concernées.',
    ],
  ),
  _LegalBlock(
    heading: '6. Données à caractère personnel',
    paragraphs: [
      'Le traitement des données personnelles est décrit dans les Conditions '
          'Générales d\'Utilisation (onglet « CGU », section « Données à '
          'caractère personnel »). Conformément au Règlement (UE) 2016/679 '
          '(RGPD) et à la loi « Informatique et Libertés », vous disposez de '
          'droits d\'accès, de rectification, d\'effacement, de limitation, '
          'd\'opposition et de portabilité.',
      'Pour exercer ces droits ou pour toute question relative à vos données, '
          'contactez l\'éditeur à l\'adresse indiquée à la section 1. Vous '
          'pouvez également introduire une réclamation auprès de la CNIL '
          '(www.cnil.fr).',
    ],
  ),
  _LegalBlock(
    heading: '7. Cookies et traceurs',
    paragraphs: [
      'L\'Application utilise des cookies et technologies similaires '
          '(stockage local) strictement nécessaires à son fonctionnement '
          '(session d\'authentification, préférences, sécurité). Le cas '
          'échéant, des traceurs de mesure d\'audience ou tiers ne sont '
          'déposés qu\'après recueil de votre consentement, que vous pouvez '
          'retirer à tout moment.',
    ],
  ),
  _LegalBlock(
    heading: '8. Responsabilité',
    paragraphs: [
      'L\'éditeur s\'efforce d\'assurer l\'exactitude et la mise à jour des '
          'informations diffusées, sans pouvoir en garantir l\'exhaustivité ni '
          'l\'absence d\'erreur. Les informations de géolocalisation, de '
          'positionnement des points d\'intérêt et de suivi en direct sont '
          'fournies à titre indicatif et peuvent comporter des imprécisions '
          'liées aux données GPS ou aux sources tierces.',
      'L\'éditeur ne saurait être tenu responsable des dommages directs ou '
          'indirects résultant de l\'accès ou de l\'utilisation du Service, '
          'notamment en cas d\'indisponibilité, d\'interruption, de perte de '
          'données ou de la présence de virus.',
    ],
  ),
  _LegalBlock(
    heading: '9. Liens hypertextes',
    paragraphs: [
      'Le Service peut contenir des liens vers des sites tiers. L\'éditeur '
          'n\'exerce aucun contrôle sur ces sites et décline toute '
          'responsabilité quant à leur contenu ou à leur politique de '
          'confidentialité.',
    ],
  ),
  _LegalBlock(
    heading: '10. Droit applicable',
    paragraphs: [
      'Les présentes mentions légales sont régies par le droit français. En '
          'cas de litige, et à défaut de résolution amiable, les tribunaux '
          'français seront compétents, sous réserve des règles impératives '
          'protégeant les consommateurs.',
    ],
  ),
];

// ===========================================================================
// CONTENU — CONDITIONS GÉNÉRALES D'UTILISATION (CGU)
// ===========================================================================

const List<_LegalBlock> _cgu = [
  _LegalBlock(
    heading: 'Article 1 — Objet',
    paragraphs: [
      'Les présentes Conditions Générales d\'Utilisation (« CGU ») ont pour '
          'objet de définir les modalités et conditions dans lesquelles '
          'l\'utilisateur (« vous », « l\'Utilisateur ») accède au service '
          'MASLIVE et l\'utilise. En accédant au Service ou en créant un '
          'compte, vous reconnaissez avoir lu, compris et accepté sans réserve '
          'les présentes CGU.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 2 — Acceptation et modification',
    paragraphs: [
      'L\'utilisation du Service vaut acceptation pleine et entière des '
          'présentes CGU. L\'éditeur se réserve le droit de les modifier à tout '
          'moment. Les CGU applicables sont celles en vigueur à la date de '
          'votre utilisation. En cas de modification substantielle, vous en '
          'serez informé par un moyen approprié.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 3 — Accès au Service',
    paragraphs: [
      'Le Service est accessible gratuitement pour ses fonctionnalités de '
          'base, sous réserve des frais de connexion et d\'équipement à votre '
          'charge. Certaines fonctionnalités nécessitent la création d\'un '
          'compte et/ou la souscription d\'une offre payante (voir Article 7).',
      'L\'éditeur s\'efforce d\'assurer la disponibilité du Service 24h/24, '
          'sans obligation de résultat. L\'accès peut être suspendu, notamment '
          'pour des raisons de maintenance, de sécurité ou de force majeure, '
          'sans que cela n\'ouvre droit à indemnité.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 4 — Inscription et compte',
    paragraphs: [
      'La création d\'un compte requiert des informations exactes, complètes '
          'et à jour. Vous êtes responsable de la confidentialité de vos '
          'identifiants et de toute activité effectuée depuis votre compte.',
      '• Vous devez avoir la capacité juridique de contracter ; les mineurs '
          'doivent obtenir l\'autorisation de leur représentant légal.',
      '• Vous vous engagez à informer sans délai l\'éditeur de toute '
          'utilisation non autorisée de votre compte.',
      '• Un compte professionnel (« compte entreprise ») peut être soumis à '
          'des vérifications complémentaires (par exemple un numéro SIRET).',
    ],
  ),
  _LegalBlock(
    heading: 'Article 5 — Règles d\'utilisation',
    paragraphs: [
      'Vous vous engagez à utiliser le Service conformément à sa destination, '
          'aux lois en vigueur et aux présentes CGU. Il est notamment interdit :',
      '• de porter atteinte à l\'ordre public, aux bonnes mœurs ou aux droits '
          'de tiers ;',
      '• de publier des contenus illicites, diffamatoires, trompeurs, '
          'contrefaisants ou portant atteinte à la vie privée ;',
      '• de tenter d\'accéder frauduleusement au Service, de le perturber '
          '(intrusion, injection, surcharge) ou d\'en extraire les données de '
          'façon massive et automatisée ;',
      '• d\'usurper l\'identité d\'un tiers ou de fournir de fausses '
          'informations, notamment de localisation.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 6 — Contenus des utilisateurs',
    paragraphs: [
      'Vous conservez la propriété des contenus que vous publiez (photos, '
          'textes, points d\'intérêt, etc.). Vous concédez toutefois à '
          'l\'éditeur une licence non exclusive, gratuite et pour la durée '
          'légale de protection, d\'héberger, reproduire et afficher ces '
          'contenus dans le seul but de faire fonctionner et promouvoir le '
          'Service.',
      'Vous garantissez détenir les droits nécessaires sur les contenus '
          'publiés. L\'éditeur peut retirer tout contenu manifestement '
          'illicite ou contraire aux CGU, sans préavis.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 7 — Achats, abonnements et paiements',
    paragraphs: [
      'Le Service peut proposer des achats de produits ou de contenus, ainsi '
          'que des abonnements (par exemple une offre « premium »). Les prix '
          'sont indiqués en euros, toutes taxes comprises le cas échéant, avant '
          'validation de la commande.',
      '• Les paiements sont traités par le prestataire Stripe ; l\'éditeur '
          'n\'a pas accès aux données complètes de votre moyen de paiement.',
      '• Les abonnements sont, sauf mention contraire, reconductibles ; vous '
          'pouvez les résilier depuis votre compte dans les conditions '
          'indiquées lors de la souscription.',
      '• Droit de rétractation : pour les consommateurs, un droit de '
          'rétractation de 14 jours peut s\'appliquer, sauf exceptions légales '
          '(notamment pour les contenus numériques dont l\'exécution a '
          'commencé avec votre accord et renoncement exprès).',
      '• Les modalités détaillées de vente (Conditions Générales de Vente) '
          'sont, le cas échéant, présentées au moment de l\'achat.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 8 — Place de marché et vendeurs tiers',
    paragraphs: [
      'Lorsque le Service met en relation des acheteurs avec des vendeurs '
          'tiers (boutiques, photographes, organisateurs), l\'éditeur agit en '
          'qualité d\'intermédiaire technique. Le contrat de vente est conclu '
          'directement entre l\'acheteur et le vendeur, qui demeure seul '
          'responsable de ses offres, de la conformité des produits ou '
          'contenus et de leurs obligations légales.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 9 — Propriété intellectuelle',
    paragraphs: [
      'Le Service, sa marque, ses logos et l\'ensemble de ses composants sont '
          'protégés (voir « Mentions légales », section 4). Aucune disposition '
          'des présentes CGU ne saurait être interprétée comme une cession de '
          'droits de propriété intellectuelle à votre profit.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 10 — Données à caractère personnel',
    paragraphs: [
      'L\'éditeur, en qualité de responsable de traitement, collecte et '
          'traite des données personnelles pour les finalités suivantes : '
          'création et gestion de compte, fourniture des fonctionnalités '
          '(cartographie, suivi en direct, boutique), sécurité, support, '
          'facturation et respect des obligations légales.',
      '• Bases légales : exécution du contrat (CGU), intérêt légitime, '
          'consentement (notamment géolocalisation en temps réel et '
          'notifications) et obligations légales.',
      '• Destinataires / sous-traitants : Google Firebase (hébergement, '
          'authentification, base de données, notifications), Stripe '
          '(paiements) et Mapbox (cartographie).',
      '• Transferts hors UE : certaines données peuvent être hébergées ou '
          'traitées hors de l\'Union européenne (notamment aux États-Unis) ; '
          'ces transferts sont encadrés par des garanties appropriées '
          '(clauses contractuelles types de la Commission européenne).',
      '• Durée de conservation : les données sont conservées pour la durée '
          'nécessaire aux finalités, puis archivées ou supprimées conformément '
          'aux durées légales.',
      '• Vos droits : accès, rectification, effacement, limitation, '
          'opposition et portabilité. Vous pouvez les exercer auprès de '
          'l\'éditeur (voir « Mentions légales », section 1) et introduire une '
          'réclamation auprès de la CNIL (www.cnil.fr).',
    ],
  ),
  _LegalBlock(
    heading: 'Article 11 — Géolocalisation',
    paragraphs: [
      'Certaines fonctionnalités reposent sur la géolocalisation de votre '
          'appareil et, le cas échéant, le partage de votre position en temps '
          'réel (suivi de groupe, cartes vivantes). Ces fonctions ne sont '
          'activées qu\'avec votre autorisation, que vous pouvez révoquer à '
          'tout moment dans les réglages de votre appareil ou de '
          'l\'Application.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 12 — Responsabilité',
    paragraphs: [
      'Le Service est fourni « en l\'état ». L\'éditeur ne garantit pas '
          'l\'absence d\'erreurs ou d\'interruptions et ne saurait être tenu '
          'responsable des dommages indirects. Les données de localisation '
          'étant indicatives, vous restez responsable de vos décisions et '
          'déplacements.',
      'La responsabilité de l\'éditeur ne saurait être engagée en cas de '
          'force majeure, de fait d\'un tiers ou d\'une mauvaise utilisation '
          'du Service par l\'Utilisateur. Les présentes stipulations '
          's\'appliquent sans préjudice des droits impératifs reconnus aux '
          'consommateurs.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 13 — Suspension et résiliation',
    paragraphs: [
      'En cas de manquement aux présentes CGU, l\'éditeur peut suspendre ou '
          'résilier votre accès, le cas échéant sans préavis en cas de '
          'manquement grave. Vous pouvez à tout moment cesser d\'utiliser le '
          'Service et demander la suppression de votre compte.',
    ],
  ),
  _LegalBlock(
    heading: 'Article 14 — Droit applicable et litiges',
    paragraphs: [
      'Les présentes CGU sont soumises au droit français. En cas de litige, '
          'vous êtes invité à contacter l\'éditeur afin de rechercher une '
          'solution amiable. Conformément à l\'article L.612-1 du Code de la '
          'consommation, le consommateur peut recourir gratuitement à un '
          'médiateur de la consommation [À COMPLÉTER : nom et coordonnées du '
          'médiateur, si applicable]. À défaut d\'accord, les tribunaux '
          'compétents seront déterminés selon les règles de droit commun.',
    ],
  ),
];
