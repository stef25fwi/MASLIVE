import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/mapbox_style_url.dart';

class StartupMapStyleService {
  StartupMapStyleService._();

  static final StartupMapStyleService instance = StartupMapStyleService._();

  static const String _collection = 'config';
  static const String _document = 'appStartup';
  static const String _fieldStyleUrl = 'defaultHomeMapStyleUrl';

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection(_collection)
      .doc(_document);

  Future<String?> getDefaultStyleUrl() async {
    final snapshot = await _doc.get();
    return tryNormalizeMapboxStyleUrl(snapshot.data()?[_fieldStyleUrl] as String?);
  }

  Future<void> saveDefaultStyleUrl(String? styleUrl) async {
    final normalized = tryNormalizeMapboxStyleUrl(styleUrl);
    await _doc.set(
      <String, Object?>{
        _fieldStyleUrl:
            normalized == null || normalized.isEmpty ? FieldValue.delete() : normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}