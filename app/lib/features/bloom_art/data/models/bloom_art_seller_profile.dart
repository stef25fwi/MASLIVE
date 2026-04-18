import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String profileType;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => artistName.trim().isNotEmpty ? artistName.trim() : fullName.trim();

  BloomArtSellerProfile copyWith({
    String? id,
    String? userId,
    String? profileType,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BloomArtSellerProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profileType: profileType ?? this.profileType,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'profileType': profileType,
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
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory BloomArtSellerProfile.fromMap(String id, Map<String, dynamic> map) {
    return BloomArtSellerProfile(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      profileType: (map['profileType'] ?? 'je_me_lance').toString(),
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
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  factory BloomArtSellerProfile.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BloomArtSellerProfile.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  static DateTime? _toDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}