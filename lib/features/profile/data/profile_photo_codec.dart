import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Shrinks a cropped photo so a profile picture stays small enough to upload.
Uint8List encodeProfileJpeg(Uint8List bytes, {int maxSide = 512}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('That photo could not be read');
  }
  final longest = math.max(decoded.width, decoded.height);
  final resized = longest <= maxSide
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height
              ? maxSide
              : (decoded.width * maxSide / longest).round(),
          height: decoded.height > decoded.width
              ? maxSide
              : (decoded.height * maxSide / longest).round(),
        );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}
