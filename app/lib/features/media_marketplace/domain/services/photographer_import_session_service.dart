import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/media_gallery_model.dart';
import '../../data/models/photographer_profile_model.dart';
import 'media_bulk_upload_service.dart';

@immutable
class PhotographerImportSession {
  const PhotographerImportSession({
    required this.sessionId,
    required this.photographerId,
    required this.galleryId,
    required this.folderName,
    required this.totalFiles,
    required this.completedFiles,
    required this.failedFiles,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sessionId;
  final String photographerId;
  final String galleryId;
  final String folderName;
  final int totalFiles;
  final List<String> completedFiles;
  final Map<String, String> failedFiles;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get fraction =>
      totalFiles <= 0 ? 0 : completedFiles.length / totalFiles;
  bool get canResume =>
      status == 'paused' || status == 'in_progress' || status == 'failed';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sessionId': sessionId,
        'photographerId': photographerId,
        'galleryId': galleryId,
        'folderName': folderName,
        'totalFiles': totalFiles,
        'completedFiles': completedFiles,
        'failedFiles': failedFiles,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PhotographerImportSession.fromJson(Map<String, dynamic> json) {
    final rawFailed = json['failedFiles'];
    return PhotographerImportSession(
      sessionId: json['sessionId']?.toString() ?? '',
      photographerId: json['photographerId']?.toString() ?? '',
      galleryId: json['galleryId']?.toString() ?? '',
      folderName: json['folderName']?.toString() ?? '',
      totalFiles: (json['totalFiles'] as num?)?.toInt() ?? 0,
      completedFiles: (json['completedFiles'] as Iterable?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[],
      failedFiles: rawFailed is Map
          ? rawFailed.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
      status: json['status']?.toString() ?? 'paused',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  PhotographerImportSession copyWith({
    int? totalFiles,
    List<String>? completedFiles,
    Map<String, String>? failedFiles,
    String? status,
    DateTime? updatedAt,
  }) {
    return PhotographerImportSession(
      sessionId: sessionId,
      photographerId: photographerId,
      galleryId: galleryId,
      folderName: folderName,
      totalFiles: totalFiles ?? this.totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
      failedFiles: failedFiles ?? this.failedFiles,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PhotographerImportSessionService extends ChangeNotifier {
  PhotographerImportSessionService._();

  static final PhotographerImportSessionService instance =
      PhotographerImportSessionService._();

  static const String _preferenceKey =
      'maslive_photographer_import_sessions_v1';
  final MediaBulkUploadService _uploader = MediaBulkUploadService();
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-east1');
  final List<PhotographerImportSession> _sessions =
      <PhotographerImportSession>[];

  List<PhotographerImportSession> get sessions =>
      List<PhotographerImportSession>.unmodifiable(_sessions);
  bool _working = false;
  bool get working => _working;
  MediaUploadProgress? _progress;
  MediaUploadProgress? get progress => _progress;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_preferenceKey);
    _sessions.clear();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Iterable) {
        for (final item in decoded.whereType<Map>()) {
          _sessions.add(
            PhotographerImportSession.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  Future<List<XFile>> pickFolderOrBatch() async {
    final result = await FilePicker().pickFiles(
      dialogTitle: 'Sélectionne un dossier ou un lot de photos',
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null) return const <XFile>[];
    return result.files
        .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
        .map(
          (file) => XFile.fromData(
            file.bytes!,
            name: file.name,
            mimeType: _mimeType(file.extension),
          ),
        )
        .toList(growable: false);
  }

  Future<PhotographerImportSession?> startOrResume({
    required PhotographerProfileModel profile,
    required MediaGalleryModel gallery,
    required List<XFile> files,
    PhotographerImportSession? previous,
    String? folderName,
  }) async {
    if (_working || files.isEmpty) return previous;
    _working = true;
    notifyListeners();
    final now = DateTime.now();
    var session = previous ??
        PhotographerImportSession(
          sessionId:
              '${profile.photographerId}_${now.microsecondsSinceEpoch}',
          photographerId: profile.photographerId,
          galleryId: gallery.galleryId,
          folderName: folderName?.trim().isNotEmpty == true
              ? folderName!.trim()
              : 'Import ${now.day}/${now.month}/${now.year}',
          totalFiles: files.length,
          completedFiles: const <String>[],
          failedFiles: const <String, String>{},
          status: 'in_progress',
          createdAt: now,
          updatedAt: now,
        );
    _upsert(session);
    await _persistAndSync(session);

    try {
      final completed = session.completedFiles.toSet();
      final pending = <XFile>[];
      for (final file in files) {
        final key = await _fileKey(file);
        if (!completed.contains(key)) pending.add(file);
      }
      if (pending.isEmpty) {
        session = session.copyWith(
          status: 'completed',
          updatedAt: DateTime.now(),
        );
        _upsert(session);
        await _persistAndSync(session);
        return session;
      }

      final result = await _uploader.uploadPhotos(
        profile: profile,
        gallery: gallery,
        files: pending,
        onProgress: (progress) {
          _progress = progress;
          notifyListeners();
        },
      );

      final rejectedNames = result.rejectedFiles.keys.toSet();
      for (final file in pending) {
        if (!rejectedNames.contains(file.name)) {
          completed.add(await _fileKey(file));
        }
      }
      final failed = <String, String>{
        ...session.failedFiles,
        ...result.rejectedFiles,
      };
      final done = completed.length >= session.totalFiles && failed.isEmpty;
      session = session.copyWith(
        completedFiles: completed.toList(growable: false),
        failedFiles: failed,
        status: done
            ? 'completed'
            : (result.uploadedPhotoIds.isEmpty ? 'failed' : 'paused'),
        updatedAt: DateTime.now(),
      );
      _upsert(session);
      await _persistAndSync(session);
      return session;
    } catch (error) {
      session = session.copyWith(
        status: 'failed',
        updatedAt: DateTime.now(),
      );
      _upsert(session);
      await _persistAndSync(session);
      rethrow;
    } finally {
      _working = false;
      _progress = null;
      notifyListeners();
    }
  }

  Future<void> removeSession(String sessionId) async {
    _sessions.removeWhere((session) => session.sessionId == sessionId);
    await _persistLocal();
    notifyListeners();
  }

  Future<String> _fileKey(XFile file) async =>
      '${file.name}:${await file.length()}';

  void _upsert(PhotographerImportSession session) {
    final index =
        _sessions.indexWhere((item) => item.sessionId == session.sessionId);
    if (index == -1) {
      _sessions.insert(0, session);
    } else {
      _sessions[index] = session;
    }
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  Future<void> _persistAndSync(PhotographerImportSession session) async {
    await _persistLocal();
    try {
      await _functions
          .httpsCallable('savePhotographerImportSession')
          .call(<String, dynamic>{
        'photographerId': session.photographerId,
        'sessionId': session.sessionId,
        'galleryId': session.galleryId,
        'folderName': session.folderName,
        'totalFiles': session.totalFiles,
        'completedFiles': session.completedFiles,
        'failedFiles': session.failedFiles.entries
            .map(
              (entry) => <String, String>{
                'name': entry.key,
                'error': entry.value,
              },
            )
            .toList(growable: false),
        'status': session.status,
        'createdAt': session.createdAt.millisecondsSinceEpoch,
      });
    } catch (_) {
      // La copie locale permet une reprise même si le réseau est absent.
    }
  }

  Future<void> _persistLocal() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _preferenceKey,
      jsonEncode(
        _sessions.map((session) => session.toJson()).toList(growable: false),
      ),
    );
  }

  static String _mimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
