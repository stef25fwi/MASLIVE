import 'package:cloud_firestore/cloud_firestore.dart';

class BloomArtCreationType {
  const BloomArtCreationType._();

  static const String painting = 'painting';
  static const String sculpture = 'sculpture';
  static const String artisanatArt = 'artisanat_art';
  static const String photography = 'photography';
  static const String illustration = 'illustration';
  static const String ceramic = 'ceramic';
  static const String jewelryArtObjects = 'jewelry_art_objects';
  static const String digitalArt = 'digital_art';
  static const String mixedArtwork = 'mixed_artwork';

  static const List<String> values = <String>[
    painting,
    sculpture,
    artisanatArt,
    photography,
    illustration,
    ceramic,
    jewelryArtObjects,
    digitalArt,
    mixedArtwork,
  ];

  static const Map<String, String> labels = <String, String>{
    painting: 'Peinture',
    sculpture: 'Sculpture',
    artisanatArt: 'Artisanat d’art',
    photography: 'Photographie',
    illustration: 'Illustration',
    ceramic: 'Céramique',
    jewelryArtObjects: 'Bijoux / objets d’art',
    digitalArt: 'Art numérique',
    mixedArtwork: 'Œuvre mixte',
  };

  static String normalize(String? value) {
    final clean = (value ?? '').trim();
    return values.contains(clean) ? clean : artisanatArt;
  }

  static String labelOf(String? value) => labels[normalize(value)] ?? 'Artisanat d’art';
}

class BloomArtSellerProfile {
  const BloomArtSellerProfile({
    required this.id,
    required this.userId,
    required this.profileType,
    required this.fullName,
    required this.artistName,
    required this.email,
    required this.phone,
    required this.bio,
    required this.address,
    required this.city,
    required this.country,
    required this.payoutStatus,
    required this.stripeAccountLinked,
    this.creationType = BloomArtCreationType.artisanatArt,
    this.sellerStatus = 'pending',
    this.siret = '',
    this.siren = '',
    this.businessName = '',
    this.nafCode = '',
    this.businessAddress = '',
    this.postalCode = '',
    this.region = '',
    this.businessVerificationStatus = 'not_verified',
    this.businessVerificationSource = '',
    this.businessVerifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String profileType;
  final String creationType;
  final String fullName;
  final String artistName;
  final String email;
  final String phone;
  final String bio;
  final String address;
  final String city;
  final String country;
  final String payoutStatus;
  final bool stripeAccountLinked;
  final String sellerStatus;
  final String siret;
  final String siren;
  final String businessName;
  final String nafCode;
  final String businessAddress;
  final String postalCode;
  final String region;
  final String businessVerificationStatus;
  final String businessVerificationSource;
  final DateTime? businessVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => artistName.trim().isNotEmpty ? artistName.trim() : fullName.trim();
  String get creationTypeLabel => BloomArtCreationType.labelOf(creationType);
  bool get isArtisanArt => profileType == 'artisan_art' || profileType == 'artist_creator';
  bool get isLaunchGuide => profileType == 'je_me_lance' || sellerStatus == 'launch_guide';
  bool get isBusinessVerified => businessVerificationStatus == 'verified' && siret.trim().isNotEmpty;
  bool get canSell => isArtisanArt && isBusinessVerified && sellerStatus == 'active';

  BloomArtSellerProfile copyWith({
    String? id,
    String? userId,
    String? profileType,
    String? creationType,
    String? fullName,
    String? artistName,
    String? email,
    String? phone,
    String? bio,
    String? address,
    String? city,
    String? country,
    String? payoutStatus,
    bool? stripeAccountLinked,
    String? sellerStatus,
    String? siret,
    String? siren,
    String? businessName,
    String? nafCode,
    String? businessAddress,
    String? postalCode,
    String? region,
    String? businessVerificationStatus,
    String? businessVerificationSource,
    DateTime? businessVerifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BloomArtSellerProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profileType: profileType ?? this.profileType,
      creationType: creationType ?? this.creationType,
      fullName: fullName ?? this.fullName,
      artistName: artistName ?? this.artistName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      payoutStatus: payoutStatus ?? this.payoutStatus,
      stripeAccountLinked: stripeAccountLinked ?? this.stripeAccountLinked,
      sellerStatus: sellerStatus ?? this.sellerStatus,
      siret: siret ?? this.siret,
      siren: siren ?? this.siren,
      businessName: businessName ?? this.businessName,
      nafCode: nafCode ?? this.nafCode,
      businessAddress: businessAddress ?? this.businessAddress,
      postalCode: postalCode ?? this.postalCode,
      region: region ?? this.region,
      businessVerificationStatus: businessVerificationStatus ?? this.businessVerificationStatus,
      businessVerificationSource: businessVerificationSource ?? this.businessVerificationSource,
      businessVerifiedAt: businessVerifiedAt ?? this.businessVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'profileType': profileType,
      'creationType': BloomArtCreationType.normalize(creationType),
      'fullName': fullName,
      'artistName': artistName,
      'email': email,
      'phone': phone,
      'bio': bio,
      'address': address,
      'city': city,
      'country': country,
      'payoutStatus': payoutStatus,
      'stripeAccountLinked': stripeAccountLinked,
      'sellerStatus': sellerStatus,
      'siret': siret,
      'siren': siren,
      'businessName': businessName,
      'nafCode': nafCode,
      'businessAddress': businessAddress,
      'postalCode': postalCode,
      'region': region,
      'businessVerificationStatus': businessVerificationStatus,
      'businessVerificationSource': businessVerificationSource,
      if (businessVerifiedAt != null) 'businessVerifiedAt': Timestamp.fromDate(businessVerifiedAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory BloomArtSellerProfile.fromMap(String id, Map<String, dynamic> map) {
    return BloomArtSellerProfile(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      profileType: _normalizeProfileType((map['profileType'] ?? 'je_me_lance').toString()),
      creationType: BloomArtCreationType.normalize(map['creationType']?.toString()),
      fullName: (map['fullName'] ?? '').toString(),
      artistName: (map['artistName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      bio: (map['bio'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      country: (map['country'] ?? '').toString(),
      payoutStatus: (map['payoutStatus'] ?? 'pending').toString(),
      stripeAccountLinked: map['stripeAccountLinked'] == true,
      sellerStatus: (map['sellerStatus'] ?? _legacySellerStatus(map)).toString(),
      siret: (map['siret'] ?? '').toString(),
      siren: (map['siren'] ?? '').toString(),
      businessName: (map['businessName'] ?? '').toString(),
      nafCode: (map['nafCode'] ?? '').toString(),
      businessAddress: (map['businessAddress'] ?? map['address'] ?? '').toString(),
      postalCode: (map['postalCode'] ?? '').toString(),
      region: (map['region'] ?? '').toString(),
      businessVerificationStatus: (map['businessVerificationStatus'] ?? _legacyVerificationStatus(map)).toString(),
      businessVerificationSource: (map['businessVerificationSource'] ?? '').toString(),
      businessVerifiedAt: _toDate(map['businessVerifiedAt']),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  factory BloomArtSellerProfile.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BloomArtSellerProfile.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  static String _normalizeProfileType(String value) {
    return value == 'artist_creator' ? 'artisan_art' : value;
  }

  static String _legacySellerStatus(Map<String, dynamic> map) {
    final profileType = _normalizeProfileType((map['profileType'] ?? '').toString());
    if (profileType == 'je_me_lance') return 'launch_guide';
    if ((map['siret'] ?? '').toString().trim().isNotEmpty) return 'active';
    return 'pending';
  }

  static String _legacyVerificationStatus(Map<String, dynamic> map) {
    if ((map['businessVerificationStatus'] ?? '').toString().trim().isNotEmpty) {
      return map['businessVerificationStatus'].toString();
    }
    if ((map['siret'] ?? '').toString().trim().isNotEmpty) return 'verified';
    if (_normalizeProfileType((map['profileType'] ?? '').toString()) == 'je_me_lance') {
      return 'missing_siret';
    }
    return 'not_verified';
  }

  static DateTime? _toDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
