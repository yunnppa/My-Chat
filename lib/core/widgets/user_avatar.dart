import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Profile photo, or the first letter of [name] when there is no photo.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.name,
    this.imageUrl,
    this.imageBytes,
    this.radius = 20,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter = Text(
      name.isEmpty ? '?' : name.characters.first,
      style: TextStyle(fontSize: radius * 0.7),
    );
    final placeholder = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: letter,
    );
    if (imageBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        backgroundImage: MemoryImage(imageBytes!),
      );
    }
    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: ClipOval(
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(child: letter),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(child: letter);
          },
        ),
      ),
    );
  }
}

/// Public photo URL. [revision] changes after each upload so cached photos refresh.
String? profileAvatarUrl({
  required String baseUrl,
  required String userId,
  required int revision,
}) {
  if (revision <= 0 || userId.isEmpty) return null;
  final base = Uri.parse(baseUrl);
  return base
      .replace(
        path: '/v1/users/$userId/avatar',
        queryParameters: {'v': '$revision'},
      )
      .toString();
}
