import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle pour un preset historique du circuit
class CircuitPresetVersion {
  final String id;
  final String projectId;
  final String name;
  final String description;
  final DateTime createdAt;
  final String createdBy;
  final Map<String, dynamic> data;
  final int version;
  
  CircuitPresetVersion({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.createdBy,
    required this.data,
    required this.version,
  });

  factory CircuitPresetVersion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return CircuitPresetVersion(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      name: data['name'] as String? ?? 'Sans nom',
      description: data['description'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      data: Map<String, dynamic>.from(data['data'] as Map? ?? {}),
      version: data['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'projectId': projectId,
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'data': data,
      'version': version,
    };
  }
}

/// Service pour gérer l'historique des presets du circuit
class CircuitPresetService {
  final FirebaseFirestore _firestore;

  CircuitPresetService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Sauvegarder un nouveau preset
  Future<String> savePreset({
    required String projectId,
    required String name,
    required String description,
    required String createdBy,
    required Map<String, dynamic> data,
  }) async {
    final presetsRef = _firestore
        .collection('map_projects')
        .doc(projectId)
        .collection('presets');

    // Compter les versions existantes
    final count = await presetsRef.count().get();
    final version = (count.count ?? 0) + 1;

    final preset = CircuitPresetVersion(
      id: '',
      projectId: projectId,
      name: name,
      description: description,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      data: data,
      version: version,
    );

    final docRef = await presetsRef.add(preset.toFirestore());
    return docRef.id;
  }

  /// Lister tous les presets d'un projet
  Future<List<CircuitPresetVersion>> listPresets({
    required String projectId,
    int limit = 50,
  }) async {
    final snapshot = await _firestore
        .collection('map_projects')
        .doc(projectId)
        .collection('presets')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => CircuitPresetVersion.fromFirestore(doc))
        .toList();
  }

  /// Charger un preset spécifique
  Future<CircuitPresetVersion?> getPreset({
    required String projectId,
    required String presetId,
  }) async {
    final doc = await _firestore
        .collection('map_projects')
        .doc(projectId)
        .collection('presets')
        .doc(presetId)
        .get();

    if (!doc.exists) return null;
    return CircuitPresetVersion.fromFirestore(doc);
  }

  /// Supprimer un preset
  Future<void> deletePreset({
    required String projectId,
    required String presetId,
  }) async {
    await _firestore
        .collection('map_projects')
        .doc(projectId)
        .collection('presets')
        .doc(presetId)
        .delete();
  }

  /// Générer un changelog (différences entre deux versions)
  Map<String, dynamic> generateChangelog({
    required Map<String, dynamic> oldData,
    required Map<String, dynamic> newData,
  }) {
    final changes = <String, dynamic>{};

    // Comparer les champs principaux
    final fields = [
      'name',
      'description',
      'countryId',
      'eventId',
      'styleUrl',
      'perimeterPoints',
      'routePoints',
      'routeColor',
      'routeWidth',
    ];

    for (final field in fields) {
      final oldValue = oldData[field];
      final newValue = newData[field];

      if (oldValue != newValue) {
        changes[field] = {
          'old': oldValue,
          'new': newValue,
        };
      }
    }

    // Comparer les layers
    final oldLayers = (oldData['layers'] as List?)?.length ?? 0;
    final newLayers = (newData['layers'] as List?)?.length ?? 0;
    if (oldLayers != newLayers) {
      changes['layers'] = {
        'old': oldLayers,
        'new': newLayers,
      };
    }

    // Comparer les POIs
    final oldPois = (oldData['pois'] as List?)?.length ?? 0;
    final newPois = (newData['pois'] as List?)?.length ?? 0;
    if (oldPois != newPois) {
      changes['pois'] = {
        'old': oldPois,
        'new': newPois,
      };
    }

    return changes;
  }

  /// Générer un résumé lisible du changelog
  String formatChangelog(Map<String, dynamic> changes) {
    if (changes.isEmpty) {
      return 'Aucune modification détectée';
    }

    final buffer = StringBuffer();
    final fieldNames = {
      'name': 'Nom du circuit',
      'description': 'Description',
      'countryId': 'Pays',
      'eventId': 'Événement',
      'styleUrl': 'Style de carte',
      'perimeterPoints': 'Points du périmètre',
      'routePoints': 'Points du tracé',
      'routeColor': 'Couleur du tracé',
      'routeWidth': 'Largeur du tracé',
      'layers': 'Nombre de layers',
      'pois': 'Nombre de POIs',
    };

    changes.forEach((key, value) {
      final fieldName = fieldNames[key] ?? key;
      final change = value as Map<String, dynamic>;
      final oldVal = change['old'];
      final newVal = change['new'];

      if (oldVal is List) {
        buffer.writeln('• $fieldName: ${oldVal.length} → ${(newVal as List).length}');
      } else {
        buffer.writeln('• $fieldName: "$oldVal" → "$newVal"');
      }
    });

    return buffer.toString().trim();
  }
}
