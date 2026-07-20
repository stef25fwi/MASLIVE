import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

class PhotographerAvatarService {
  PhotographerAvatarService({
    ImagePicker? picker,
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : _picker = picker ?? ImagePicker(),
        _storage = storage ?? FirebaseStorage.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final ImagePicker _picker;
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  Future<String?> pickCropCompressAndUpload({
    required String photographerId,
    required String ownerUid,
  }) async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
      requestFullMetadata: true,
    );
    if (selected == null) return null;

    final raw = await selected.readAsBytes();
    final decoded = image_lib.decodeImage(raw);
    if (decoded == null) {
      throw StateError('Le fichier sélectionné n’est pas une image valide.');
    }

    final side = decoded.width < decoded.height ? decoded.width : decoded.height;
    final cropped = image_lib.copyCrop(
      decoded,
      x: (decoded.width - side) ~/ 2,
      y: (decoded.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final resized = image_lib.copyResize(
      cropped,
      width: 640,
      height: 640,
      interpolation: image_lib.Interpolation.cubic,
    );
    final encoded = Uint8List.fromList(image_lib.encodeJpg(resized, quality: 86));
    if (encoded.lengthInBytes > 2 * 1024 * 1024) {
      throw StateError('L’avatar compressé dépasse 2 Mo.');
    }

    final path = 'photographers/$photographerId/profile/avatar.jpg';
    final reference = _storage.ref(path);
    await reference.putData(
      encoded,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=86400',
        customMetadata: <String, String>{
          'ownerUid': ownerUid,
          'photographerId': photographerId,
          'kind': 'photographer_avatar',
        },
      ),
    );
    final url = await reference.getDownloadURL();
    await _firestore.collection('photographers').doc(photographerId).set(
      <String, dynamic>{
        'avatarUrl': url,
        'avatarStoragePath': path,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return url;
  }
}
