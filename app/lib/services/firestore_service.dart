import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/place_model.dart';
import '../models/group_model.dart';
import '../models/group_location_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();

  FirestoreService._internal();

  factory FirestoreService() {
    return _instance;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Récupérer tous les places (streaming)
  Stream<List<Place>> getPlacesStream() {
    return _firestore
        .collection('places')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Place.fromFirestore(doc))
              .toList();
        });
  }

  // Récupérer les places par type
  Stream<List<Place>> getPlacesByTypeStream(PlaceType type) {
    final typeStr = _typeToString(type);
    return _firestore
        .collection('places')
        .where('type', isEqualTo: typeStr)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Place.fromFirestore(doc))
              .toList();
        });
  }

  // Récupérer les places par ville
  Stream<List<Place>> getPlacesByCityStream(String city) {
    return _firestore
        .collection('places')
        .where('city', isEqualTo: city)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Place.fromFirestore(doc))
              .toList();
        });
  }

  // Ajouter un place
  Future<String> addPlace(Place place) async {
    final docRef = await _firestore
        .collection('places')
        .add(place.toFirestore());
    return docRef.id;
  }

  // Mettre à jour un place
  Future<void> updatePlace(String id, Place place) async {
    await _firestore
        .collection('places')
        .doc(id)
        .update(place.toFirestore());
  }

  // Supprimer un place
  Future<void> deletePlace(String id) async {
    await _firestore.collection('places').doc(id).delete();
  }

  String _typeToString(PlaceType type) {
    switch (type) {
      case PlaceType.market:
        return 'market';
      case PlaceType.visit:
        return 'visit';
      case PlaceType.food:
        return 'food';
    }
  }

  // ============ GROUPS ============

  // Récupérer tous les groups (streaming)
  Stream<List<Group>> getGroupsStream() {
    return _firestore
        .collection('groups')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Group.fromFirestore(doc))
              .toList();
        });
  }

  // Récupérer les groups par région
  Stream<List<Group>> getGroupsByRegionStream(String region) {
    return _firestore
        .collection('groups')
        .where('region', isEqualTo: region)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Group.fromFirestore(doc))
              .toList();
        });
  }

  // Récupérer les groups par catégorie
  Stream<List<Group>> getGroupsByCategoryStream(String category) {
    return _firestore
        .collection('groups')
        .where('category', isEqualTo: category)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Group.fromFirestore(doc))
              .toList();
        });
  }

  // Récupérer un group par ID
  Future<Group?> getGroupById(String id) async {
    final doc = await _firestore.collection('groups').doc(id).get();
    if (doc.exists) {
      return Group.fromFirestore(doc);
    }
    return null;
  }

  // Ajouter un group
  Future<String> addGroup(Group group) async {
    final docRef = await _firestore
        .collection('groups')
        .add(group.toFirestore());
    return docRef.id;
  }

  // Mettre à jour un group
  Future<void> updateGroup(String id, Group group) async {
    await _firestore
        .collection('groups')
        .doc(id)
        .update(group.toFirestore());
  }

  // Supprimer un group
  Future<void> deleteGroup(String id) async {
    await _firestore.collection('groups').doc(id).delete();
  }

  // ============ GROUP_LOCATIONS ============

  // Récupérer toutes les localisations de groupe (streaming)
  Stream<List<GroupLocation>> getGroupLocationsStream() {
    return _firestore
        .collection('group_locations')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => GroupLocation.fromFirestore(doc))
              .toList();
        });
  }

  // Récupérer la localisation d'un groupe spécifique
  Future<GroupLocation?> getGroupLocation(String groupId) async {
    final query = await _firestore
        .collection('group_locations')
        .where('groupId', isEqualTo: groupId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      return GroupLocation.fromFirestore(query.docs.first);
    }
    return null;
  }

  // Récupérer les localisations de plusieurs groupes
  Stream<List<GroupLocation>> getGroupLocationsForGroupsStream(List<String> groupIds) {
    if (groupIds.isEmpty) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('group_locations')
        .where('groupId', whereIn: groupIds)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => GroupLocation.fromFirestore(doc))
              .toList();
        });
  }

  // Ajouter/Mettre à jour la localisation d'un groupe
  Future<String> updateGroupLocation(GroupLocation location) async {
    final query = await _firestore
        .collection('group_locations')
        .where('groupId', isEqualTo: location.groupId)
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      // Mettre à jour le document existant
      final docId = query.docs.first.id;
      await _firestore
          .collection('group_locations')
          .doc(docId)
          .update(location.toFirestore());
      return docId;
    } else {
      // Créer un nouveau document
      final docRef = await _firestore
          .collection('group_locations')
          .add(location.toFirestore());
      return docRef.id;
    }
  }

  // Supprimer la localisation d'un groupe
  Future<void> deleteGroupLocation(String groupId) async {
    final query = await _firestore
        .collection('group_locations')
        .where('groupId', isEqualTo: groupId)
        .get();
    
    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }
}
