import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:commontable_ai_app/core/services/firebase_boot.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<String> uploadImageBytes(
    Uint8List bytes, {
    String folder = 'posts',
    String? objectPath,
    String contentType = 'image/jpeg',
  }) async {
    if (!FirebaseBoot.available) {
      throw StateError('Cloud storage not available');
    }
    // Allow a fixed object path (e.g., profiles/<uid>.jpg), else fall back to folder/<uuid>.jpg
    final ref = objectPath != null
        ? _storage.ref(objectPath)
        : _storage.ref().child('$folder/${_uuid.v4()}.jpg');
    final task = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public, max-age=3600',
      ),
    );
    return task.ref.getDownloadURL();
  }
}
