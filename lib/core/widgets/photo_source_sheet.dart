import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Gallery or camera, shared by profile photos and stories.
Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      );
    },
  );
}

Future<Uint8List?> pickPhoto(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 90,
    preferredCameraDevice: CameraDevice.front,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}

String photoPickerError(Object error) {
  final text = '$error'.toLowerCase();
  if (text.contains('camera_access_denied') ||
      text.contains('camera access') ||
      text.contains('photo_access_denied') ||
      text.contains('photo access')) {
    return 'Allow camera or photo access to choose a photo.';
  }
  return 'Could not open that photo.';
}
