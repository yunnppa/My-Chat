import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/data/http_chat_repository.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/profile_photo_store.dart';

final profilePhotoStoreProvider = Provider<ProfilePhotoStore>(
  (ref) => ProfilePhotoStore(),
);

final profilePhotoProvider =
    AsyncNotifierProvider<ProfilePhotoController, Uint8List?>(
      ProfilePhotoController.new,
    );

class ProfilePhotoController extends AsyncNotifier<Uint8List?> {
  @override
  Future<Uint8List?> build() async {
    final session = ref.watch(sessionProvider);
    if (session == null) return null;
    final store = ref.read(profilePhotoStoreProvider);
    try {
      final local = await store.read(session.userId);
      if (local != null && local.isNotEmpty) return local;
    } catch (_) {}
    try {
      final remote = await ref
          .read(chatRepositoryProvider)
          .downloadAvatar(session.userId);
      if (remote == null || remote.isEmpty) return null;
      try {
        await store.write(session.userId, remote);
      } catch (_) {}
      return remote;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Uint8List jpeg) async {
    final session = ref.read(sessionProvider);
    if (session == null) {
      throw ProfilePhotoException('Save a name first, then add a photo.');
    }
    try {
      await ref.read(profilePhotoStoreProvider).write(session.userId, jpeg);
    } catch (_) {
      throw ProfilePhotoException('Could not save the photo on this phone.');
    }
    state = AsyncData(jpeg);
    try {
      await ref
          .read(chatRepositoryProvider)
          .uploadAvatar(session: session, bytes: jpeg);
    } catch (error) {
      final detail = error is ChatApiException
          ? '$error'
          : 'The photo is saved on this phone, but it could not be uploaded.';
      throw ProfilePhotoException(detail);
    }
    ref.invalidate(chatsProvider);
  }
}

class ProfilePhotoException implements Exception {
  ProfilePhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}
