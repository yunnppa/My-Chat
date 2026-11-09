import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/widgets/photo_source_sheet.dart';
import 'story_preview_page.dart';

/// Gallery or camera, then privacy and a confirm-to-upload prompt. No crop.
///
/// Declining the prompt reopens the same gallery or camera.
Future<StoryDraft?> pickStoryPhoto(BuildContext context) async {
  final source = await showPhotoSourceSheet(context);
  if (source == null || !context.mounted) return null;

  while (context.mounted) {
    final Uint8List bytes;
    try {
      final picked = await pickPhoto(source);
      if (picked == null || !context.mounted) return null;
      bytes = picked;
    } catch (error) {
      throw StoryPhotoException(photoPickerError(error));
    }
    if (!context.mounted) return null;
    final result = await Navigator.of(context, rootNavigator: true)
        .push<Object?>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => StoryPreviewPage(image: bytes, source: source),
          ),
        );
    if (result is StoryDraft) return result;
    if (result == null || !context.mounted) return null;
  }
  return null;
}

class StoryPhotoException implements Exception {
  StoryPhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}
