import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/widgets/photo_source_sheet.dart';
import 'profile_photo_controller.dart';
import 'profile_photo_crop_page.dart';

/// Gallery or camera, then the crop screen. Returns the JPEG to save.
Future<Uint8List?> pickProfilePhoto(BuildContext context) async {
  final source = await showPhotoSourceSheet(context);
  if (source == null || !context.mounted) return null;

  final Uint8List bytes;
  try {
    final picked = await pickPhoto(source);
    if (picked == null || !context.mounted) return null;
    bytes = picked;
  } catch (error) {
    throw ProfilePhotoException(photoPickerError(error));
  }
  if (!context.mounted) return null;
  return Navigator.of(context, rootNavigator: true).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProfilePhotoCropPage(image: bytes, source: source),
    ),
  );
}
