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
  }) async {
    if (!FirebaseBoot.available) {
      throw StateError('Cloud storage not available');
    }
    final id = _uuid.v4();
    final ref = _storage.ref().child('$folder/$id.jpg');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }
}
