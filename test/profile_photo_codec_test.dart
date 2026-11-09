import 'dart:typed_data';

import 'package:chat_app/features/profile/data/profile_photo_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('profile photos are saved as a small jpeg', () {
    final source = img.Image(width: 800, height: 600);
    img.fill(source, color: img.ColorRgb8(20, 80, 160));
    final jpeg = encodeProfileJpeg(Uint8List.fromList(img.encodePng(source)));
    final decoded = img.decodeJpg(jpeg);

    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(512));
    expect(decoded.height, lessThanOrEqualTo(512));
  });
}
