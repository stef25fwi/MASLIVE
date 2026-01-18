import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final bool isAdmin;
  final DateTime createdAt;

  User({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.isAdmin = false,
    required this.createdAt,
  });

  // Convertir depuis Firestore document
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final created = data['createdAt'] as Timestamp?;
    return User(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      isAdmin: data['isAdmin'] as bool? ?? false,
      createdAt: created != null ? created.toDate() : DateTime.now(),
    );
  }

  factory User.fromMap(String uid, Map<String, dynamic> data) {
    final created = data['createdAt'] as Timestamp?;
    return User(
      uid: uid,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      isAdmin: data['isAdmin'] as bool? ?? false,
      createdAt: created != null ? created.toDate() : DateTime.now(),
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isAdmin': isAdmin,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Copie avec modifications
  User copyWith({
    String? displayName,
    String? photoUrl,
    bool? isAdmin,
  }) {
    return User(
      uid: uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt,
    );
  }
}
