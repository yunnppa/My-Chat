import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Keeps the signed-in user's cropped profile photo on this phone.
class ProfilePhotoStore {
  Future<Uint8List?> read(String userId) async {
    final file = await _file(userId);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  Future<void> write(String userId, Uint8List bytes) async {
    final file = await _file(userId);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<File> _file(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    final safe = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${directory.path}/avatars/$safe.jpg');
  }
}
